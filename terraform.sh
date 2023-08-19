#!/bin/bash

PRYSM_VERSION="HEAD-09d761"
GETH_VERSION="alltools-v1.12.2"

export PRYSM_VERSION=${PRYSM_VERSION}
export GETH_VERSION=${GETH_VERSION}


echo "Cleaning up images"

docker stop bc-node01 && docker rm bc-node01
docker stop bc-node02 && docker rm bc-node02
docker stop bc-node03 && docker rm bc-node03

docker stop bc-beacon-01 && docker rm bc-beacon-01
docker stop bc-beacon-02 && docker rm bc-beacon-02
docker stop bc-beacon-03 && docker rm bc-beacon-03

docker stop bc-validator-01 && docker rm bc-validator-01
docker stop bc-validator-02 && docker rm bc-validator-02
docker stop bc-validator-03 && docker rm bc-validator-03

echo "Creating folders"

rm -rf ./node01
rm -rf ./node02
rm -rf ./node03

mkdir ./node01/
mkdir ./node02/
mkdir ./node03/

mkdir ./node01/execution
mkdir ./node01/consensus

mkdir ./node02/execution
mkdir ./node02/consensus

mkdir ./node03/execution
mkdir ./node03/consensus

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

cp node01-compose.yml ./node01
cp node02-compose.yml ./node02
cp node03-compose.yml ./node03

cp ./shared/config.yml ./node01/consensus
cp ./shared/genesis.ssz ./node01/consensus

cp ./shared/config.yml ./node02/consensus
cp ./shared/genesis.ssz ./node02/consensus

cp ./shared/config.yml ./node03/consensus
cp ./shared/genesis.ssz ./node03/consensus

cp ./shared/jwtsecret ./node01
cp ./shared/jwtsecret ./node02
cp ./shared/jwtsecret ./node03

cp ./shared/password.txt ./node01/execution
cp ./shared/password.txt ./node02/execution
cp ./shared/password.txt ./node03/execution

cp -r ./shared/keystore ./node01/execution
cp -r ./shared/keystore ./node02/execution
cp -r ./shared/keystore ./node03/execution

cp ./shared/genesis.json ./node01/execution
cp ./shared/genesis.json ./node02/execution
cp ./shared/genesis.json ./node03/execution

./genkey.sh ./node01/consensus/n1-p2p-priv.key
./genkey.sh ./node02/consensus/n2-p2p-priv.key
./genkey.sh ./node03/consensus/n3-p2p-priv.key


echo "Generating genesis block to the execution nodes..."

docker run --rm \
-v $(pwd)/node01/execution:/datadir \
-v /etc/localtime:/etc/localtime:ro \
-it ethereum/client-go:${GETH_VERSION} geth \
--datadir /datadir \
init /datadir/genesis.json

docker run --rm \
-v $(pwd)/node02/execution:/datadir \
-v /etc/localtime:/etc/localtime:ro \
-it ethereum/client-go:${GETH_VERSION} geth \
--datadir /datadir \
init /datadir/genesis.json 

docker run --rm \
-v $(pwd)/node03/execution:/datadir \
-v /etc/localtime:/etc/localtime:ro \
-it ethereum/client-go:${GETH_VERSION} geth \
--datadir /datadir \
init /datadir/genesis.json



cd ./node01 && docker compose -f node01-compose.yml up -d && cd ..

echo "Waiting to node 01 brings up..."
sleep 15

echo "Consensus 01 P2P address: "
echo ""
curl localhost:35108/p2p | awk -F/ip4 '{print "/ip4" $NF}' | grep tcp > n1-p2p.txt
cat n1-p2p.txt

cd ./node02 && docker compose -f node02-compose.yml up -d && cd ..

echo "Waiting to node 02 brings up..."
sleep 15

echo "Consensus 02 P2P address: "
echo ""
curl localhost:35208/p2p | awk -F/ip4 '{print "/ip4" $NF}' | grep tcp > n2-p2p.txt
cat n2-p2p.txt

cd ./node03 && docker compose -f node03-compose.yml up -d && cd ..

echo "Waiting to node 03 brings up..."
sleep 15

echo "Consensus 03 P2P address: "
echo ""
curl localhost:35308/p2p | awk -F/ip4 '{print "/ip4" $NF}' | grep tcp > n3-p2p.txt
cat n3-p2p.txt

export N1P2PNODE=$(head -1 n1-p2p.txt)
export N2P2PNODE=$(head -1 n2-p2p.txt)
export N3P2PNODE=$(head -1 n3-p2p.txt)


tar -czf /home/suporte/predefined.tar.gz ./*
chown suporte:suporte /home/suporte/predefined.tar.gz

# admin.addPeer("enode://9883eb202e46710a6e8d3849350be48464820f18fd726f95f5b79c8a4ac19ce0e3ae647bfc1117785aad95dc61e91126a7371193c66d6219e697147aed00462f@bc-node01:30303");
# admin.addPeer("enode://e1df03c5d090be245c96649efdac0c34199d4d7ee9bed5c61b5b092cd91d21a67a78f8bd3384dc842d4fab9bc7f61eeffdc77b9498ca7762992d3961d9d91d17@bc-node02:30303");
# admin.addPeer("enode://96fea1f360718d24e2dd93814304a0729fe6a0f02e5c8faae1ed3bae3a835a2554e87988b1abd90e602604400c4e03d256ec9a9367c0d21c35abf8fb64b017ba@bc-node03:30303");

echo "Pairing Execution peers..."

curl -vX POST 'http://localhost:35100' --header 'Content-Type: application/json' -d @pn2.json
curl -vX POST 'http://localhost:35100' --header 'Content-Type: application/json' -d @pn3.json
curl -vX POST 'http://localhost:35200' --header 'Content-Type: application/json' -d @pn1.json
curl -vX POST 'http://localhost:35200' --header 'Content-Type: application/json' -d @pn3.json
curl -vX POST 'http://localhost:35300' --header 'Content-Type: application/json' -d @pn1.json
curl -vX POST 'http://localhost:35300' --header 'Content-Type: application/json' -d @pn2.json

