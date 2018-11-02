inputDir = "/dockershare/in/";
outputDir = "/dockershare/out/";

// Params
GaussRad = 3;
Thr = 60;
OpenRad = 7; 

arg = getArgument();
parts = split(arg, ",");

setBatchMode(true);

for(i=0; i<parts.length; i++) {
	nameAndValue = split(parts[i], "=");
	if (indexOf(nameAndValue[0], "input")>-1) inputDir=nameAndValue[1];
	if (indexOf(nameAndValue[0], "output")>-1) outputDir=nameAndValue[1];
	if (indexOf(nameAndValue[0], "gauss_rad")>-1) GaussRad=nameAndValue[1];
	if (indexOf(nameAndValue[0], "threshold")>-1) Thr=nameAndValue[1];
	if (indexOf(nameAndValue[0], "open_rad")>-1) OpenRad=nameAndValue[1];
		
}

images = getFileList(inputDir);
for(i=0; i<images.length; i++) {
	image = images[i];
		if (endsWith(image, ".tif")) {
			run("Bio-Formats Importer", "open="+inputDir + "/" + image+" autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
			// Workflow
			run("Gaussian Blur...", "sigma="+d2s(GaussRad,0)+" stack");
			setThreshold(Thr, 255);
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Default background=Dark");
			run("Watershed", "stack");
			run("Minimum...", "radius="+d2s(OpenRad,0)+" stack");
			rename("Mask");
			run("Connected Components Labeling", "connectivity=26 type=[16 bits]");
			run("Maximum...", "radius="+d2s(OpenRad,0)+" stack");
			selectImage("Mask");
			run("Ultimate Points", "stack");
			setThreshold(1, 255);
			run("Convert to Mask", "method=Default background=Dark");
			run("Divide...", "value=255 stack");
			run("16-bit");
			imageCalculator("Multiply create stack", "Mask","Mask-lbl");
			run("Grays");
			run("Properties...", "channels=1 slices=1 frames="+nSlices);
			// End of workflow
			if (!endsWith(image, ".ome.tif")) image = replace(image, ".tif", ".ome.tif");
			run("Bio-Formats Exporter", "save="+outputDir + "/" + image+" export compression=Uncompressed");
			nameWithoutOme = replace(image, ".ome", ""); 			
			File.rename(outputDir+"/"+image, outputDir+"/"+nameWithoutOme);
			run("Close All");
		}
}
run("Quit");
