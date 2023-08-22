#!/bin/bash

if [ "$#" -lt 3 ]
then
  echo "Use: ./deploy-exporter.sh <GETH_NAME> <BEACON_NAME> <INDEX>" 
  echo "   Ex: ./deploy-exporter.sh geth-01 beacon-01 1"
  exit 1
fi
echo ""

GETH_NAME=$1
BEACON_NAME=$2
EXPORTER_INDEX=$3

CONTAINER_NAME=("bc-exporter-$EXPORTER_INDEX")

let PORT=(9*1000+100*EXPORTER_INDEX)

echo "Will use port "${PORT}

docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}

docker run -d --name=${CONTAINER_NAME} --hostname=${CONTAINER_NAME} \
--network=interna \
--restart=always \
-p ${PORT}:9090 \
-v /etc/localtime:/etc/localtime:ro \
ethpandaops/ethereum-metrics-exporter \
--consensus-url=http://${BEACON_NAME}:3500 \
--execution-url=http://${GETH_NAME}:8545