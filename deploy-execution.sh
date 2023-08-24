#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|     DO NOT RUN THIS SCRIPT    |"
echo "*********************************"
echo "  User deploy-full.sh instead"
echo ""

if [ "$#" -lt 6 ]
then
  echo "Use: ./deploy-execution.sh <NODE_DIR> <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <NODE_INDEX> <THIS_HOST_IP>" 
  echo "   Ex: ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1 192.168.100.34 | 127.0.0.1"
  echo "   or "
  echo "   Ex: ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1"  
  exit 1
fi

CONTAINER_NAME=$1
GETH_VERSION=$2
PRYSM_VERSION=$3
NETWORK_ID=$4
NODE_INDEX=$5
# HOST_IP=`ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}'`
# HOST_IP=$(curl --silent https://api.ipify.org)
HOST_IP=$6
NODE_NAME=("node-$NODE_INDEX")
NODE_DIR=$(pwd)/${NODE_NAME}
EXECUTION=${NODE_DIR}/execution
CONSENSUS=${NODE_DIR}/consensus
TOKEN_DIR=${EXECUTION}
JWT_FILE="${TOKEN_DIR}/jwtsecret"
NODE_KEY_FILE="${EXECUTION}/node.key"

echo ""

echo $NODE_NAME
echo $NODE_DIR
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NETWORK_ID
echo $NODE_INDEX
echo $HOST_IP
echo $EXECUTION
echo $CONSENSUS
echo $TOKEN_DIR
echo $JWT_FILE
echo $NODE_KEY_FILE

rm -rf ${NODE_DIR} 
mkdir -p ${NODE_DIR}
mkdir -p ${CONSENSUS}
mkdir -p ${EXECUTION}

echo ""

if [ -f "./genesis-block.tar.gz" ]; 
then
  echo "Extracting genesis block..."
  tar -xf genesis-block.tar.gz -C ${NODE_DIR}
else  
  echo "Genesis block not found. Creating a new one..."
  cp ./config/genesis.json ${EXECUTION}
  cp ./config/config.yml ${CONSENSUS}
  cp -r ./config/keystore ${EXECUTION}
  docker run --rm \
  -v ${NODE_DIR}/execution:/execution \
  -v ${NODE_DIR}/consensus:/consensus \
  -v /etc/localtime:/etc/localtime:ro \
  gcr.io/prysmaticlabs/prysm/cmd/prysmctl:${PRYSM_VERSION} testnet generate-genesis \
  --fork=bellatrix \
  --num-validators=64 \
  --output-ssz=/consensus/genesis.ssz \
  --chain-config-file=/consensus/config.yml \
  --geth-genesis-json-in=/execution/genesis.json \
  --geth-genesis-json-out=/execution/genesis.json

  docker run --rm \
  -v ${NODE_DIR}/execution:/datadir \
  -v /etc/localtime:/etc/localtime:ro \
  -it ethereum/client-go:${GETH_VERSION} \
  --datadir /datadir \
  init /datadir/genesis.json

  tar -czf ./genesis-block.tar.gz -C ${NODE_DIR} . 
  echo "Done. Your genesis block was also saved in genesis-block.tar.gz"

fi

if [ ! -f "$JWT_FILE" ]; 
then
    echo "JWT Token does not exist. Generating..."
    docker run --rm \
    -v ${TOKEN_DIR}:/execution \
    -it gcr.io/prysmaticlabs/prysm/beacon-chain:${PRYSM_VERSION} generate-auth-secret \
    --output-file=/execution/jwtsecret
    echo "Done."
fi

echo "Generating node key to ENODE static address..."
openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout > keypair
cat keypair | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//' > ${NODE_KEY_FILE}
rm -rf priv && rm -rf keypair
NODE_KEY_HEX=$(head -n 1 ${NODE_KEY_FILE})

echo "Deploying Execution $CONTAINER_NAME"
echo " Node index $NODE_INDEX"

let RPC_PORT=(35*1000+100*NODE_INDEX)
let WS_PORT=(35*1000+100*NODE_INDEX+1)
let P2P_PORT=(35*1000+100*NODE_INDEX+3)

echo "Exposing ports: "
echo "RPC : $RPC_PORT as 8545"
echo "WS  : $WS_PORT as 8546"
echo "P2P : $P2P_PORT as 30303"
echo ""
echo "External IP is : $HOST_IP"
echo ""

# Don't know why must to unlock this wallet.
# --unlock=0x48deeb959d9af454ec406d2a686e50728036e19e
# --password=/execution/password.txt

# docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}

docker run --name=${CONTAINER_NAME} --hostname=${CONTAINER_NAME} \
--network=interna \
-v ${EXECUTION}:/execution \
-v /etc/localtime:/etc/localtime:ro \
-p ${RPC_PORT}:8545 \
-p ${WS_PORT}:8546 \
-p ${P2P_PORT}:30303 \
-d ethereum/client-go:$GETH_VERSION \
--http \
--http.api="admin,debug,web3,eth,txpool,engine,personal,net" \
--http.addr="0.0.0.0" \
--http.corsdomain="*" \
--http.vhosts=* \
--ws \
--ws.addr="0.0.0.0" \
--ws.api="admin,debug,web3,eth,txpool,engine,personal,net" \
--ws.origins='*' \
--authrpc.vhosts=* \
--authrpc.addr=0.0.0.0 \
--authrpc.jwtsecret=/execution/jwtsecret \
--datadir=/execution \
--allow-insecure-unlock \
--nodiscover \
--syncmode=full \
--gcmode=archive \
--identity=${CONTAINER_NAME} \
--cache=4096 \
--maxpeers=10 \
--verbosity=5 \
--networkid=${NETWORK_ID} \
--nodekeyhex="${NODE_KEY_HEX}" \
--netrestrict="0.0.0.0/0" \
--nat=extip:${HOST_IP}

echo "Waiting to node brings up..."
sleep 5

echo "Taking ENODE address..."

if [ ! -d "./peers" ]; then
  mkdir ./peers
fi
rm -f ./peers/$CONTAINER_NAME.nodeinfo
rm -f ./peers/$CONTAINER_NAME.enode

curl --silent \
-X POST \
-H "Content-Type: application/json" \
--data '{"jsonrpc": "2.0", "id": 1, "method": "admin_nodeInfo", "params": []}' \
http://localhost:${RPC_PORT} \
-o ./peers/$CONTAINER_NAME.nodeinfo

temp=`cat peers/$CONTAINER_NAME.nodeinfo | jq -r '.result.enode'`
ENODE_ADDR=${temp/30303/"$P2P_PORT"}

ENODE_RPC='{
    "jsonrpc": "2.0",
    "method": "admin_addPeer",
    "id": 1, 
    "params": [
        "'$ENODE_ADDR'"
    ]
}'
echo ${ENODE_RPC} > ./peers/$CONTAINER_NAME.enode

echo "Registering peers..." 

search_dir=./peers
for entry in "$search_dir"/*.enode
do
  echo "$entry"
  curl --silent -X POST http://localhost:${RPC_PORT} --header 'Content-Type: application/json' -d @$entry
done

echo ""
echo "Done! You may want to save the ./peers directory"
echo "  contents to put it in another host and allow them to sync."