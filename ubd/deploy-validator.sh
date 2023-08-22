#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|    VALIDATOR NODE DEPLOYER    |"
echo "*********************************"
echo "  > Deploy a Validator Container"
echo ""

if [ "$#" -lt 4 ]
then
  echo "Use: ./deploy-validator.sh <VALIDATOR_NAME> <PRYSM_VERSION> <VALIDATOR_INDEX> <BEACON_NAME>" 
  echo "   Ex: ./deploy-validator.sh validator-01 HEAD-09d761 1 beacon-01"
  exit 1
fi

CONTAINER_NAME=$1
PRYSM_VERSION=$2
NODE_INDEX=$3
BEACON_NODE=$4
NODE_NAME=("node-$NODE_INDEX")
NODE_DIR=$(pwd)/${NODE_NAME}
EXECUTION=${NODE_DIR}/execution
CONSENSUS=${NODE_DIR}/consensus

docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}

docker run --name=${CONTAINER_NAME} --hostname=${CONTAINER_NAME} \
--network=interna \
-v ${CONSENSUS}:/consensus \
-v ${EXECUTION}:/execution \
-v /etc/localtime:/etc/localtime:ro \
-d gcr.io/prysmaticlabs/prysm/validator:$PRYSM_VERSION \
--beacon-rpc-provider=${BEACON_NODE}:4000 \
--datadir=/consensus/validatordata \
--accept-terms-of-use \
--interop-num-validators=32 \
--interop-start-index=0 \
--chain-config-file=/consensus/config.yml \
--force-clear-db \
--graffiti=$1
