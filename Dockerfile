FROM neubiaswg5/fiji-base

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
