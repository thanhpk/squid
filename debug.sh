#!/bin/sh

# RUN THIS SCRIPT TO LOOK INSIDE THE DOCKER CONTAINER

docker build -t thanhpk/squid:test .

docker rm -f squid 2>/dev/null || true

docker run -dit --name squid \
 -e SQUID_USER=user1 \
 -e SQUID_PASS=s3cret \
 -e FRP_SERVER_ADDR=frp.subiz.net \
 -e FRP_TOKEN=$FRP_TOKEN \
 -e FRP_REMOTE_PORT=17001 \
 thanhpk/squid:test

docker exec -it squid sh
