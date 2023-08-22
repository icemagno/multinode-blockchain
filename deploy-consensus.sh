#!/bin/bash

echo ""
echo ""
echo ""
echo "*********************************"
echo "|    CONSENSUS NODE DEPLOYER    |"
echo "*********************************"
echo "  > Deploy a Beacon Container"
echo "  > I'll need JQ to read JSON files..."
echo "  >   Be sure you have jq installed."
echo "  >   Ex. apt install jq"
echo ""

if [ "$#" -lt 6 ]
then
  echo "Use: ./deploy-consensus.sh <BEACON_NAME> <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <BEACON_INDEX> <EXECUTION_NAME> [THIS_HOST_IP]" 
  echo "   Ex: ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 geth-01 192.168.100.34"
  echo "   or"
  echo "   Ex: ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 geth-01"
  exit 1
fi

CONTAINER_NAME=$1
GETH_VERSION=$2
PRYSM_VERSION=$3
NETWORK_ID=$4
NODE_INDEX=$5
EXECUTION_NAME=$6
NODE_NAME=("node-$NODE_INDEX")
NODE_DIR=$(pwd)/${NODE_NAME}
EXECUTION=${NODE_DIR}/execution
CONSENSUS=${NODE_DIR}/consensus
TOKEN_DIR=${EXECUTION}
JWT_FILE="${TOKEN_DIR}/jwtsecret"

# HOST_IP=`ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}'`
# HOST_IP=$(curl --silent https://api.ipify.org)
if [ "$#" -eq 7 ]
then
  HOST_IP=$7
else
  HOST_IP='127.0.0.1'
fi    

echo $NODE_NAME
echo $NODE_DIR
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NETWORK_ID
echo $NODE_INDEX
echo $HOST_IP
echo $EXECUTION_NAME
echo $EXECUTION
echo $CONSENSUS
echo $TOKEN_DIR
echo $JWT_FILE

if [ ! -f "$JWT_FILE" ]; then
    echo "JWT Token does not exist."
    echo "  Make sure you have a Execution Container deployed here."
    exit 1
fi

NODE_KEY_FILE="${CONSENSUS}/priv.key"
echo "Generating P2P Private Key..."
openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout > keypair
cat keypair | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//' > ${NODE_KEY_FILE}
rm -rf priv && rm -rf keypair

echo "Deploying Beacon $CONTAINER_NAME"

let P2P_UDP=(35*1000+100*NODE_INDEX+4)
let P2P_TCP=(35*1000+100*NODE_INDEX+5)
let RPC_API=(35*1000+100*NODE_INDEX+6)
let RPC_PORT=(35*1000+100*NODE_INDEX+8)

echo "Exposing ports: "
echo "P2P UDP : $P2P_UDP as 12000"
echo "P2P TCP : $P2P_TCP as 13000"
echo "RPC     : $RPC_PORT as 8080"
echo "RPC API : $RPC_API as 3500"
echo ""
echo "External IP is : $HOST_IP"
echo ""

# --suggested-fee-recipient=0x48deeb959d9af454ec406d2a686e50728036e19e
# --rpc-port=4000
# --interop-eth1data-votes=true \

docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}

docker run --name=${CONTAINER_NAME} --hostname=${CONTAINER_NAME} \
--network=interna \
-v ${CONSENSUS}:/consensus \
-v ${EXECUTION}:/execution \
-v /etc/localtime:/etc/localtime:ro \
-p ${P2P_UDP}:12000 \
-p ${P2P_TCP}:13000 \
-p ${RPC_PORT}:8080 \
-p ${RPC_API}:3500 \
-d gcr.io/prysmaticlabs/prysm/beacon-chain:$PRYSM_VERSION \
--datadir=/consensus/beacondata \
--min-sync-peers=0 \
--genesis-state=/consensus/genesis.ssz \
--bootstrap-node= \
--chain-config-file=/consensus/config.yml \
--chain-id=${NETWORK_ID} \
--rpc-host=0.0.0.0 \
--monitoring-host=0.0.0.0 \
--grpc-gateway-host=0.0.0.0 \
--contract-deployment-block=0 \
--execution-endpoint=http://${EXECUTION_NAME}:8551 \
--accept-terms-of-use \
--jwt-secret=/execution/jwtsecret \
--disable-staking-contract-check \
--enable-debug-rpc-endpoints \
--p2p-priv-key=/consensus/priv.key ${PEER_LIST} --suggested-fee-recipient=0x48deeb959d9af454ec406d2a686e50728036e19e

echo "Waiting to beacon brings up..."
sleep 5


echo "Registering peers..."
search_dir=./peers
for entry in "$search_dir"/*.p2p
do
   P2P_ADDRESS=$(head -1 $entry)
   if [[ $P2P_ADDRESS == *"/ip4/"* ]]; then
     IFS='/' read -r -a ARRAY_ADDRESS <<< "$P2P_ADDRESS"
     PORTA_RPC=${ARRAY_ADDRESS[0]}
     PEER=/${ARRAY_ADDRESS[1]}/${ARRAY_ADDRESS[2]}/${ARRAY_ADDRESS[3]}/${ARRAY_ADDRESS[4]}/${ARRAY_ADDRESS[5]}${ARRAY_ADDRESS[6]}
     REMOTE_IP=${ARRAY_ADDRESS[2]}
     URL="http://"${REMOTE_IP}:${PORTA_RPC}"/prysm/node/trusted_peers"
     DATA=" {\"addr\":\""${PEER}"\"}"
     curl \
	     ${URL} \
	     -X POST \
	     -H "Content-Type: application/json" \
	     -d ${DATA}	
   fi
done


echo "Saving my own peer connection info so you can use it to connect to others..."
rm -f ./peers/$CONTAINER_NAME.p2p
P2P_API=("http://localhost:$RPC_PORT/p2p")
curl \
${P2P_API} | awk -F/tcp '{print "/tcp" $NF}' | grep p2p > ./peers/$CONTAINER_NAME.temp
P2P_ADDRESS=$(head -1 ./peers/$CONTAINER_NAME.temp)
temp=(${RPC_API}"/ip4/"${HOST_IP}${P2P_ADDRESS})
P2P_EXTERNAL=${temp/13000/"$P2P_TCP"}
echo ${P2P_EXTERNAL} > ./peers/$CONTAINER_NAME.p2p
rm -f ./peers/$CONTAINER_NAME.temp


echo ""
echo "Done! You may want to save the ./peers directory"
echo "  contents to put it in another host and allow them to sync."

