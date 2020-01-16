inputDir = "/dockershare/in/";
outputDir = "/dockershare/out/";

// Params
GaussRad = 3;
Thr = 60;
ErodeRad = 7; 

arg = getArgument();
parts = split(arg, ",");

setBatchMode(true);

for(i=0; i<parts.length; i++) {
	nameAndValue = split(parts[i], "=");
	if (indexOf(nameAndValue[0], "input")>-1) inputDir=nameAndValue[1];
	if (indexOf(nameAndValue[0], "output")>-1) outputDir=nameAndValue[1];
	if (indexOf(nameAndValue[0], "ij_radius")>-1) GaussRad=nameAndValue[1];
	if (indexOf(nameAndValue[0], "ij_threshold")>-1) Thr=nameAndValue[1];
	if (indexOf(nameAndValue[0], "ij_erode_radius")>-1) ErodeRad=nameAndValue[1];
		
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
			run("Minimum...", "radius="+d2s(ErodeRad,0)+" stack");
			rename("Mask");
			run("Connected Components Labeling", "connectivity=26 type=[16 bits]");
			run("Maximum...", "radius="+d2s(ErodeRad,0)+" stack");
			selectImage("Mask");
			run("Maximum...", "radius="+d2s(ErodeRad,0)+" stack");
			run("Ultimate Points", "stack");
			setThreshold(1, 255);
			run("Convert to Mask", "method=Default background=Dark");
			run("Divide...", "value=255 stack");
			run("16-bit");
			imageCalculator("Multiply create stack", "Mask","Mask-lbl");
			run("Grays");
			run("Properties...", "channels=1 slices=1 frames="+nSlices);
			mergePoints();			
			// End of workflow
			if (!endsWith(image, ".ome.tif")) image = replace(image, ".tif", ".ome.tif");
			run("Bio-Formats Exporter", "save="+outputDir + "/" + image+" export compression=Uncompressed");
			nameWithoutOme = replace(image, ".ome", ""); 			
			File.rename(outputDir+"/"+image, outputDir+"/"+nameWithoutOme);
			run("Close All");
		}
}
//run("Quit");

function mergePoints() { 
	for (i = 1; i < nSlices; i++) {
		setSlice(i);
		getStatistics(area, mean, min, max, std, histogram);
		getHistogram(values, counts, max+1, 0, max+1);
		for (j = 1; j < counts.length; j++) {
			if (counts[j]>1) mergePointsWithValue(round(values[j]));
		}
	}
}

function mergePointsWithValue(value) {
	setThreshold(value, value);
	run("Create Selection");
	run("Clear", "slice");
	getSelectionBounds(x, y, width, height);
	setColor(value);
	fillOval(x+(width/2), y+(height/2), 1, 1);
	run("Select None");
}
