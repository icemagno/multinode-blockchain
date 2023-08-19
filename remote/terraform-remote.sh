#!/bin/bash

PRYSM_VERSION="HEAD-09d761"
GETH_VERSION="v1.12.2"

export PRYSM_VERSION=${PRYSM_VERSION}
export GETH_VERSION=${GETH_VERSION}


echo "Cleaning up images"

docker stop bc-node01 && docker rm bc-node01
docker stop bc-beacon-01 && docker rm bc-beacon-01
docker stop bc-validator-01 && docker rm bc-validator-01

echo "Creating folders"
rm -rf ./node01
mkdir ./node01/
mkdir ./node01/execution
mkdir ./node01/consensus
rm -rf ./shared/genesis.ssz
rm -rf ./shared/password.txt
rm -rf ./shared/jwtsecret

echo "Preparing password file"
echo B@rtholom3usGusm@n > ./shared/password.txt

echo "Preparing RPC JWT token"

docker run --rm \
-v $(pwd)/shared:/secret \
-it gcr.io/prysmaticlabs/prysm/beacon-chain:${PRYSM_VERSION} generate-auth-secret \
--output-file=/secret/jwtsecret

echo "Generating consensus genesis file..."

docker run --rm \
-v $(pwd)/shared:/consensus \
-v $(pwd)/shared/genesis.json:/genesis.json \
-v $(pwd)/shared/config.yml:/config.yml \
-v /etc/localtime:/etc/localtime:ro \
gcr.io/prysmaticlabs/prysm/cmd/prysmctl:${PRYSM_VERSION} testnet generate-genesis \
--fork=bellatrix \
--num-validators=64 \
--output-ssz=/consensus/genesis.ssz \
--chain-config-file=/config.yml \
--geth-genesis-json-in=/genesis.json \
--geth-genesis-json-out=/genesis.json

cp remote-compose.yml ./node01
cp ./shared/config.yml ./node01/consensus
cp ./shared/genesis.ssz ./node01/consensus
cp ./shared/jwtsecret ./node01/execution
cp ./shared/password.txt ./node01/execution
cp -r ./shared/keystore ./node01/execution
cp ./shared/genesis.json ./node01/execution
./genkey.sh ./node01/consensus/n1-p2p-priv.key

echo "Generating genesis block to the execution nodes..."

docker run --rm \
-v $(pwd)/node01/execution:/datadir \
-v /etc/localtime:/etc/localtime:ro \
-it ethereum/client-go:${GETH_VERSION} \
--datadir /datadir \
init /datadir/genesis.json

export N1P2PNODE=$(head -1 n1-p2p.txt)
export N2P2PNODE=$(head -1 n2-p2p.txt)
export N3P2PNODE=$(head -1 n3-p2p.txt)

cd ./node01 && docker compose -f remote-compose.yml up -d && cd .. 

echo "Waiting to node 01 brings up..."
sleep 15

tar -czf /home/suporte/predefined.tar.gz ./*
chown suporte:suporte /home/suporte/predefined.tar.gz

echo "Pairing Execution peers..."

curl -vX POST 'http://localhost:35100' --header 'Content-Type: application/json' -d @pn1.json
curl -vX POST 'http://localhost:35100' --header 'Content-Type: application/json' -d @pn2.json
curl -vX POST 'http://localhost:35100' --header 'Content-Type: application/json' -d @pn3.json



