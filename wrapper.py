import os
import sys
from subprocess import call

from cytomine import CytomineJob
from cytomine.models import Annotation, Job, ImageInstanceCollection, AnnotationCollection, Property, ImageGroupCollection, ImageInstance, ImageSequenceCollection
from shapely.affinity import affine_transform
from shapely.geometry import Polygon, MultiPolygon, Point, LineString
from skimage import io
from skimage.measure import points_in_poly, label as label_fn
from annotation_exporter import mask_to_points_2d, AnnotationSlice
from neubiaswg5.metrics import computemetrics_batch
from itertools import groupby
from shapely.geometry import LineString
import numpy as np

def main(argv):
    # 0. Initialize Cytomine client and job
    with CytomineJob.from_cli(argv) as cj:
        cj.job.update(status=Job.RUNNING, progress=0, statusComment="Initialisation...")

        # 1. Create working directories on the machine:
        # - WORKING_PATH/in: input images
        # - WORKING_PATH/out: output images
        # - WORKING_PATH/ground_truth: ground truth images
        # - WORKING_PATH/tmp: temporary path
        base_path = "{}".format(os.getenv("HOME"))
        gt_suffix = "_lbl"
        working_path = os.path.join(base_path, str(cj.job.id))
        in_path = os.path.join(working_path, "in")
        out_path = os.path.join(working_path, "out")
        gt_path = os.path.join(working_path, "ground_truth")
        tmp_path = os.path.join(working_path, "tmp")

        if not os.path.exists(working_path):
            os.makedirs(working_path)
            os.makedirs(in_path)
            os.makedirs(out_path)
            os.makedirs(gt_path)
            os.makedirs(tmp_path)

        # 2. Download the images (first input, then ground truth image)

        cj.job.update(progress=1, statusComment="Downloading images (to {})...".format(in_path))
        image_group = ImageGroupCollection().fetch_with_filter("project", cj.parameters.cytomine_id_project)

        input_images = [i for i in image_group if gt_suffix not in i.name]
        gt_images = [i for i in image_group if gt_suffix in i.name]

        for input_image in input_images:
            input_image.download(os.path.join(in_path, "{id}.tif"))

        for gt_image in gt_images:
            related_name = gt_image.name.replace(gt_suffix, '')
            related_image = [i for i in input_images if related_name == i.name]
            if len(related_image) == 1:
                gt_image.download(os.path.join(gt_path, "{}.tif".format(related_image[0].id)))


        # 3. Call the image analysis workflow using the run script
        cj.job.update(progress=25, statusComment="Launching workflow...")
        command = "/usr/bin/xvfb-run ./ImageJ-linux64 -macro macro.ijm " \
		"\"input={}, output={}, gauss_rad={}, threshold={}, open_rad={}\" -batch".format(in_path, out_path, cj.parameters.ij_gauss_radius, cj.parameters.ij_threshold, cj.parameters.ij_open_radius)

        return_code = call(command, shell=True, cwd="/fiji")  # waits for the subprocess to return

        if return_code != 0:
            err_desc = "Failed to execute the ImageJ macro (return code: {})".format(return_code)
            cj.job.update(progress=50, statusComment=err_desc)
            raise ValueError(err_desc)
		

if __name__ == "__main__":
    main(sys.argv[1:])

