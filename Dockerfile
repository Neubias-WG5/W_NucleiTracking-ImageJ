FROM python:3.6

# ---------------------------------------------------------------------------------------------------------------------
# Install Cytomine python client
RUN git clone https://github.com/cytomine-uliege/Cytomine-python-client.git
RUN cd /Cytomine-python-client && git checkout tags/v2.2.0 && pip install .
RUN rm -r /Cytomine-python-client

# ---------------------------------------------------------------------------------------------------------------------
# Install Neubias-W5-Utilities (annotation exporter, compute metrics, helpers,...)
RUN git clone https://github.com/Neubias-WG5/neubiaswg5-utilities.git
RUN cd /neubiaswg5-utilities/ && git checkout tags/v0.5.2a && pip install .

# install utilities binaries
RUN chmod +x /neubiaswg5-utilities/bin/*
RUN cp /neubiaswg5-utilities/bin/* /usr/bin/

# cleaning
RUN rm -r /neubiaswg5-utilities

# Install Java
RUN apt-get update && apt-get install openjdk-8-jdk -y && apt-get clean

# keep re-install of numpy as long as this is open: https://github.com/scikit-image/scikit-image/issues/3586
# latest scikit-image is incompatible with latest numpy (1.16) on pip. This is being fixed by skimage team.

RUN pip install numpy==1.13.0

# Install FIJI


# Install virtual X server
RUN apt-get update && apt-get install -y unzip xvfb libx11-dev libxtst-dev libxrender-dev

# Install Fiji.
RUN wget https://downloads.imagej.net/fiji/Life-Line/fiji-linux64-20170530.zip
RUN unzip fiji-linux64-20170530.zip
RUN mv Fiji.app/ fiji

# create a sym-link with the name jars/ij.jar that is pointing to the current version jars/ij-1.nm.jar
RUN cd /fiji/jars && ln -s $(ls ij-1.*.jar) ij.jar

# Add fiji to the PATH
ENV PATH $PATH:/fiji

RUN mkdir -p /fiji/data

# Clean up
RUN rm fiji-linux64-20170530.zip

# install FeatureJ

RUN cd /fiji/plugins && \
wget -O imagescience.jar \
https://imagescience.org/meijering/software/download/imagescience.jar

RUN cd /fiji/plugins && \
wget -O FeatureJ_.jar \
https://imagescience.org/meijering/software/download/FeatureJ_.jar

# install MorphoLibJ

RUN cd /fiji/plugins && \
wget https://github.com/ijpb/MorphoLibJ/releases/download/v1.3.6/MorphoLibJ_-1.3.6.jar

# add the local files

ADD NucleiTracking.ijm /fiji/macros/macro.ijm
ADD wrapper.py /app/wrapper.py

# set the entrypoint
ENTRYPOINT ["python", "/app/wrapper.py"]
