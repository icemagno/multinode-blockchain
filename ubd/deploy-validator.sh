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

NODE_NAME=$(pwd)/$1
PRYSM_VERSION=$2
NODE_INDEX=$3
BEACON_NODE=$4
EXECUTION=${NODE_NAME}/execution
CONSENSUS=${NODE_NAME}/consensus

rm -rf ${NODE_NAME} 
mkdir ${NODE_NAME}

echo "Extracting genesis block..."
tar -xf genesis-block.tar.gz -C ${NODE_NAME}

docker stop $1 && docker rm $1

docker run --name=$1 --hostname=$1 \
--network=interna \
-v ${CONSENSUS}:/consensus \
-v /etc/localtime:/etc/localtime:ro \
-d gcr.io/prysmaticlabs/prysm/validator:$PRYSM_VERSION \
--beacon-rpc-provider=${BEACON_NODE}:4000 \
--datadir=/consensus/validatordata \
--accept-terms-of-use \
--interop-num-validators=64 \
--interop-start-index=0 \
--chain-config-file=/consensus/config.yml \
--force-clear-db \
--graffiti=$1
