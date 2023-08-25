#!/bin/bash


if [ "$#" -lt 5 ]
then
  echo "Use: ./deploy-light.sh <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <NODE_INDEX> <THIS_HOST_IP> [CHECKPOINT_ADDR]" 
  echo "   Ex: ./deploy-light.sh v1.12.2 HEAD-09d761 8658 1 192.168.100.34 | 127.0.0.1"
  echo "   or "
  echo "   Ex: ./deploy-light.sh v1.12.2 HEAD-09d761 8658 1 192.168.100.34 192.168.100.39:35106"
  exit 1
fi

if ! command -v jq &> /dev/null
then
  echo "I'll need JQ to read JSON files..."
  echo "   Be sure you have jq installed."
  echo "   Ex. apt install jq"
  echo "   I need this to proceed. Aborting..."
  echo ""
  exit 1
fi

echo ""
read -p "Press any key to continue... " -n1 -s
echo ""

GETH_VERSION=$1
PRYSM_VERSION=$2
NET_ID=$3
NODE_INDEX=$4
HOST_IP=$5
NODE_NAME=("geth-$NODE_INDEX")
BEACON_NAME=("beacon-$NODE_INDEX")
VALIDATOR_NAME=("validator-$NODE_INDEX")

mkdir ./peers

#  ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1 192.168.100.34"
./deploy-execution.sh ${NODE_NAME} ${GETH_VERSION} ${PRYSM_VERSION} ${NET_ID} ${NODE_INDEX} ${HOST_IP}

# ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 node-01 192.168.100.34"
CHECKPOINT_NODE=""
if [ "$#" -eq 6 ]
then
  ./deploy-consensus.sh ${BEACON_NAME} ${GETH_VERSION} ${PRYSM_VERSION} ${NET_ID} ${NODE_INDEX} ${NODE_NAME} ${HOST_IP} $6
else
  ./deploy-consensus.sh ${BEACON_NAME} ${GETH_VERSION} ${PRYSM_VERSION} ${NET_ID} ${NODE_INDEX} ${NODE_NAME} ${HOST_IP}
fi

echo "You're done!!"