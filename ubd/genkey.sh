#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|         KEY GENERATOR         |"
echo "*********************************"
echo "  > Generate JWT RPC Token"
echo ""

if [ "$#" -lt 2 ]
then
  echo "Use: ./genkey.sh <NODE_NAME> <PRYSM_VERSION>"
  echo "   Ex: ./genkey.sh node-01 HEAD-09d761"
  exit 1
fi

NODE_NAME=$1
PRYSM_VERSION=$2

CONSENSUS=$(pwd)/${NODE_NAME}/consensus
TOKEN_DIR=$(pwd)/jwt-token

if [ ! -d "${TOKEN_DIR}" ]; then
  mkdir -p ${TOKEN_DIR}
fi

if [ ! -d "${CONSENSUS}" ]; then
  mkdir -p ${CONSENSUS}
fi


if [ ! -d "${CONSENSUS}" ]; then
  mkdir ${CONSENSUS}
fi

cp ${TOKEN_DIR}/jwtsecret ${CONSENSUS}