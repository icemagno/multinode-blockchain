#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|    EXECUTION NODE DEPLOYER    |"
echo "*********************************"
echo "  > Deploy a Execution Container"
echo ""

if [ "$#" -lt 5 ]
then
  echo "Use: ./deploy-execution.sh <NODE_NAME> <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <NODE_INDEX> [THIS_HOST_IP]" 
  echo "   Ex: ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1 192.168.100.34"
  echo "   or "
  echo "   Ex: ./deploy-execution.sh geth-01 v1.12.2 HEAD-09d761 8658 1"  
  exit 1
fi

if ! command -v jq &> /dev/null
then
  echo "  > I'll need JQ to read JSON files..."
  echo "  > Be sure you have jq installed."
  echo "  > Ex. apt install jq"
  echo "  > I need this to proceed. Aborting..."
  echo ""
  exit 1
fi

echo "              --------------------------"
echo "              -:: A.T.T.E.N.T.I.O.N ::- "
echo "              --------------------------"
echo ""
echo " If you want to add another peers to this one, please"
echo "  save all *.enode files from another hosts to the 'peers' folder"
echo "  under this script folder."
echo "" 
echo " Be sure you have the chain genesis file here."
echo "  - If you don't have one, you can either generate or download from "
echo "    another chain to join it. Use 'make-genesis.sh' to generate. "
echo ""
echo "  - If you have one already, you can copy the ./peers directory content"
echo "    into all nodes ./peers directories and run 'addpeers.sh' to allow"
echo "    the nodes to sync. Better if you put it here before running this script."
echo ""
read -p "Press any key to continue... " -n1 -s

NODE_NAME=$(pwd)/$1
GETH_VERSION=$2
PRYSM_VERSION=$3
NETWORK_ID=$4
NODE_INDEX=$5
EXECUTION=${NODE_NAME}/execution
CONSENSUS=${NODE_NAME}/consensus

# HOST_IP=`ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}'`
# HOST_IP=$(curl --silent https://api.ipify.org)
if [ "$#" -eq 6 ]
then
  HOST_IP=$6
else
  HOST_IP='127.0.0.1'
fi    

rm -rf ${NODE_NAME} 
mkdir ${NODE_NAME}

TOKEN_DIR=$(pwd)/jwt-token
JWT_FILE="${TOKEN_DIR}/jwtsecret"

echo "Will work on these folders:"

echo ${EXECUTION}
echo ${CONSENSUS}
echo ${JWT_FILE}

echo ""

echo "Extracting genesis block..."
tar -xf genesis-block.tar.gz -C ${NODE_NAME}

if [ ! -f "$JWT_FILE" ]; then
    echo "JWT Token does not exist. Generating..."
    ./genkey.sh $1 ${PRYSM_VERSION} 
    echo "Done."
fi
cp ${JWT_FILE} ${EXECUTION}

NODE_KEY_FILE="${EXECUTION}/node.key"
echo "Generating node key to ENODE static address..."
openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout > keypair
cat keypair | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//' > ${NODE_KEY_FILE}
rm -rf priv && rm -rf keypair
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
echo "External IP is : $HOST_IP"
echo ""

# Don't know why must to unlock this wallet.
# --unlock=0x48deeb959d9af454ec406d2a686e50728036e19e
# --password=/execution/password.txt

docker stop $1 && docker rm $1

docker run --name=$1 --hostname=$1 \
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

echo ""
echo "Done! You may want to save the ./peers directory"
echo "  contents to put it in another host and allow them to sync."