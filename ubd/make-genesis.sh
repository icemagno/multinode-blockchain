#!/bin/bash

if [ "$#" -lt 3 ]
then
  echo "Use: ./make-genesis.sh <PRYSM_VERSION> <GETH_VERSION>"
  echo "   Ex: ./make-genesis.sh HEAD-09d761 v1.12.2 mycoolpassword"
  exit 1
fi

PRYSM_VERSION=$1
GETH_VERSION=$2
PASSWORD=$3

echo "Creating genesis block..."

rm -rf ./genesis
rm -rf ./genesis-block.tar.gz
mkdir ./genesis
mkdir ./genesis/consensus
mkdir ./genesis/execution

cp ./shared/config.yml ./genesis/consensus
cp ./shared/genesis.json ./genesis/execution
cp -r ./shared/keystore ./genesis/execution

echo "Generating consensus genesis file..."

docker run --rm \
-v $(pwd)/genesis/execution:/execution \
-v $(pwd)/genesis/consensus:/consensus \
-v /etc/localtime:/etc/localtime:ro \
gcr.io/prysmaticlabs/prysm/cmd/prysmctl:${PRYSM_VERSION} testnet generate-genesis \
--fork=bellatrix \
--num-validators=64 \
--output-ssz=/consensus/genesis.ssz \
--chain-config-file=/consensus/config.yml \
--geth-genesis-json-in=/execution/genesis.json \
--geth-genesis-json-out=/execution/genesis.json

docker run --rm \
-v $(pwd)/genesis/execution:/datadir \
-v /etc/localtime:/etc/localtime:ro \
-it ethereum/client-go:${GETH_VERSION} \
--datadir /datadir \
init /datadir/genesis.json

# PASSWORD=$(printf '%s' $(echo "$RANDOM" | md5sum) | cut -c 1-32)
# This password will be used to unlock wallets if necessary.
# I'll not controll that.
# Be sure you already generated wallets in 'keystore' directory
# using this password.
# Some examples are using "unlock" flag to unlock some
# wallets but I really don't know why so I'll not do it.
# echo ${PASSWORD} > ./genesis/execution/password.txt

tar -czf ./genesis-block.tar.gz -C genesis . 

echo "Done. Your genesis block was also saved in genesis-block.tar.gz"
