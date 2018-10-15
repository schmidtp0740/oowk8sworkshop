#!/bin/bash
docker build -t worker . &&
docker run -it --privileged -v /var/run/docker.sock:/var/run/docker.sock  -v `pwd`/scripts:/root/scripts worker /bin/bash