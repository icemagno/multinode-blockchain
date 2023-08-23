#!/bin/bash


if [ "$#" -lt 4 ]
then
  echo "Use: ./deploy-full.sh <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <NODE_INDEX> [THIS_HOST_IP]" 
  echo "   Ex: ./deploy-full.sh v1.12.2 HEAD-09d761 8658 1 192.168.100.34"
  echo "   or "
  echo "   Ex: ./deploy-full.sh v1.12.2 HEAD-09d761 8658 1"  
  exit 1
fi

echo ""
read -p "Press any key to continue... " -n1 -s
echo ""

GETH_VERSION=$1
PRYSM_VERSION=$2
NET_ID=$3
NODE_INDEX=$4

NODE_NAME=("geth-$NODE_INDEX")
BEACON_NAME=("beacon-$NODE_INDEX")
VALIDATOR_NAME=("validator-$NODE_INDEX")

docker stop ${NODE_NAME} && docker rm ${NODE_NAME}
docker stop ${BEACON_NAME} && docker rm ${BEACON_NAME}
docker stop ${VALIDATOR_NAME} && docker rm ${VALIDATOR_NAME}

if [ "$#" -eq 5 ]
then
  HOST_IP=$5
else
  HOST_IP='127.0.0.1'
fi

#  ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1 192.168.100.34"
./deploy-execution.sh ${NODE_NAME} ${GETH_VERSION} ${PRYSM_VERSION} ${NET_ID} ${NODE_INDEX} ${HOST_IP}

# ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 node-01 192.168.100.34"
./deploy-consensus.sh ${BEACON_NAME} ${GETH_VERSION} ${PRYSM_VERSION} ${NET_ID} ${NODE_INDEX} ${NODE_NAME} ${HOST_IP}

# ./deploy-validator.sh validator-01 HEAD-09d761 1 beacon-01"
./deploy-validator.sh ${VALIDATOR_NAME} ${PRYSM_VERSION} ${NODE_INDEX} ${BEACON_NAME}
