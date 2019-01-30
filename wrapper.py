import sys
import os
from subprocess import call
from cytomine.models import Job
from subprocess import call
from skimage import io
from itertools import groupby
from shapely.geometry import LineString, MultiPoint
from shapely.affinity import affine_transform
from cytomine.models import Annotation,AnnotationCollection, ImageInstance, ImageSequenceCollection
from neubiaswg5.exporter.mask_to_points import mask_to_points_3d
from neubiaswg5 import CLASS_PRTTRK
from neubiaswg5.helpers import NeubiasJob, prepare_data, upload_data, upload_metrics

def main(argv):

    with NeubiasJob.from_cli(argv) as nj:

        problem_cls = CLASS_PRTTRK 
        nj.job.update(status=Job.RUNNING, progress=0, statusComment="Initialisation...")


        in_images, gt_images, in_path, gt_path, out_path, tmp_path = prepare_data(problem_cls, nj, is_2d=False, **nj.flags)

        # 2. Call the image analysis workflow
        nj.job.update(progress=25, statusComment="Launching workflow...")
        command = "/usr/bin/xvfb-run ./ImageJ-linux64 -macro macro.ijm " \
		  "\"input={}, output={}, gauss_rad={}, threshold={}, open_rad={}\" -batch".format(in_path, out_path, nj.parameters.ij_gauss_radius, nj.parameters.ij_threshold, nj.parameters.ij_open_radius)

        return_code = call(command, shell=True, cwd="/fiji")  # waits for the subprocess to return

        if return_code != 0:
            err_desc = "Failed to execute the ImageJ macro (return code: {})".format(return_code)
            nj.job.update(progress=50, statusComment=err_desc)
            raise ValueError(err_desc)
        nj.job.update(progress=30, statusComment="Workflow finished...")	
        
        # 4. Create and upload annotations
        for image in nj.monitor(in_images, start=60, end=80, period=0.1, prefix="Extracting and uploading tracks from point-masks"):
            file = "{}.tif".format(image.id)
            path = os.path.join(out_path, file)
            data = io.imread(path)

            # extract objects
            objects = mask_to_points_3d(data, time=True)

            objects = sorted(objects, key=lambda annotationSlice: annotationSlice.time)    
            objects = sorted(objects, key=lambda annotationSlice: annotationSlice.label)    
            grouped = groupby(objects,  key=lambda annotationSlice: annotationSlice.label)
	    
            image_sequences = ImageSequenceCollection().fetch_with_filter("imagegroup", image.id)
	    
            depth_to_image = {iseq.channel: iseq.image for iseq in image_sequences}
            height = ImageInstance().fetch(image_sequences[0].image).height
	    
            collection = AnnotationCollection()
	    
            groups = []
            uniquekeys = []
            for k, g in grouped:
                groups.append(list(g))      # Store group iterator as a list
                uniquekeys.append(k)
	    
                for key, group in zip(uniquekeys, groups):
                   listOfPoints = []
                   for oSlice in group:
                       listOfPoints.append((oSlice.polygon.x, oSlice.polygon.y))
                   shape = LineString(listOfPoints)
                   # shape = MultiPoint(listOfPoints)
                   for oSlice2 in group:
                       polygon = affine_transform(shape, [1, 0, 0, -1, 0, height])
                       annotation = Annotation(location=polygon.wkt, id_image=depth_to_image[oSlice2.time], id_project=nj.parameters.cytomine_id_project, property=[{"key": "index", "value": str(oSlice2.label)}])
                       collection.append(annotation)
		
            collection.save()
            print("Found {} objects in this image {}.".format(len(objects), image.id))

        # 5. Compute and upload the metrics       
        nj.job.update(progress=80, statusComment="Computing and uploading metrics (if necessary)...")
        upload_metrics(problem_cls, nj, in_images, gt_path, out_path, tmp_path, **nj.flags)

        # 6. End the job
        nj.job.update(status=Job.TERMINATED, progress=100, statusComment="Finished.")

if __name__ == "__main__":
    main(sys.argv[1:])

