#!/bin/bash


NODE_NAME=$1
BEACON_NAME=$2

docker stop bc-exporter && docker rm bc-exporter

docker run -d --name=bc-exporter --hostname=bc-exporter \
--network=interna \
--restart=always \
-p 9093:9090 \
-v /etc/localtime:/etc/localtime:ro \
ethpandaops/ethereum-metrics-exporter \
--consensus-url=http://${BEACON_NAME}:3500 \
--execution-url=http://${NODE_NAME}:8545