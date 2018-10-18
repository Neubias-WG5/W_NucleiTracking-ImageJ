inputDir = "/dockershare/766/in/";
outputDir = "/dockershare/766/out/";

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
			open(inputDir + "/" + image);
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
			save(outputDir + "/" + image);
			run("Close All");
		}
}
run("Quit");
