#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|    EXECUTION NODE DEPLOYER    |"
echo "*********************************"
echo "  > Deploy a Execution Container"
echo "  > I'll need JQ to read JSON files..."
echo "  >   Be sure you have jq installed."
echo "  >   Ex. apt install jq"
echo ""

if [ "$#" -lt 5 ]
then
  echo "Use: ./deploy-execution.sh <NODE_NAME> <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <NODE_INDEX>" 
  echo "   Ex: ./deploy-execution.sh node-01 v1.12.2 HEAD-09d761 8658 1"
  exit 1
fi

echo "Note: If you want to add another peers to this one, please"
echo "  save all *.enode files from another hosts to the 'peers' folder"
echo "  under this script folder."
echo "" 

read -p "Press any key to continue... " -n1 -s

NODE_NAME=$(pwd)/$1
GETH_VERSION=$2
PRYSM_VERSION=$3
NETWORK_ID=$4
NODE_INDEX=$5
EXECUTION=${NODE_NAME}/execution
CONSENSUS=${NODE_NAME}/consensus

rm -rf ${NODE_NAME} 
mkdir ${NODE_NAME}

TOKEN_DIR=$(pwd)/jwt-token
JWT_FILE="${TOKEN_DIR}/jwtsecret"


echo "Will work on these folders:"

echo ${EXECUTION}
echo ${CONSENSUS}
echo ${JWT_FILE}
echo ${PASSWORD_FILE}

echo ""


if [ ! -f "$JWT_FILE" ]; then
    echo "JWT Token does not exist. Generating..."
    ./genkey.sh $1 ${PRYSM_VERSION} 
    echo "Done."
fi
cp ${JWT_FILE} ${EXECUTION}


PASSWORD=$(printf '%s' $(echo "$RANDOM" | md5sum) | cut -c 1-32)

echo ${PASSWORD} > ${EXECUTION/password.txt}

echo "Extracting genesis block..."
tar -xf genesis-block.tar.gz -C ${NODE_NAME}

NODE_KEY_FILE="${EXECUTION}/node.key"
echo "Generating node key to ENODE static address..."
openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout > keypair
cat keypair | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//' > ${NODE_KEY_FILE}
rm -rf priv
rm -rf keypair

NODE_KEY_HEX=$(head -n 1 ${NODE_KEY_FILE})

echo "Deploying Execution $1"

let RPC_PORT=(35*1000+100*NODE_INDEX)
let WS_PORT=(35*1000+100*NODE_INDEX+1)
let P2P_PORT=(35*1000+100*NODE_INDEX+3)

echo "Exposing ports: "
echo "RPC : $RPC_PORT as 8545"
echo "WS  : $WS_PORT as 8546"
echo "P2P : $P2P_PORT as 30303"
echo ""

#HOST_IP=`ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}'`
HOST_IP=$(curl https://api.ipify.org)

echo "External IP is : $HOST_IP"
echo ""

docker run --name=$1 --hostname=$1 \
--network=interna \
-v ${EXECUTION}:/execution \
-v /srv/blockchain/secret:/secret \
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
--password=/execution/password.txt \
--nodiscover \
--syncmode=full \
--gcmode=archive \
--identity=$1 \
--cache=4096 \
--maxpeers=50 \
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
rm -f ./peers/$1.nodeinfo
rm -f ./peers/$1.enode

curl --silent \
-X POST \
-H "Content-Type: application/json" \
--data '{"jsonrpc": "2.0", "id": 1, "method": "admin_nodeInfo", "params": []}' \
http://localhost:${RPC_PORT} \
-o ./peers/$1.nodeinfo

temp=`cat peers/$1.nodeinfo | jq -r '.result.enode'`
ENODE_ADDR=${temp/30303/"$P2P_PORT"}

ENODE_RPC='{
    "jsonrpc": "2.0",
    "method": "admin_addPeer",
    "id": 1, 
    "params": [
        "'$ENODE_ADDR'"
    ]
}'
echo ${ENODE_RPC} > ./peers/$1.enode

./addpeers.sh ${RPC_PORT}

