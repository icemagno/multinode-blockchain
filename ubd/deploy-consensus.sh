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
  echo "Use: ./deploy-consensus.sh <BEACON_NAME> <GETH_VERSION> <PRYSM_VERSION> <NET_ID> <BEACON_INDEX> <NODE_NAME> [THIS_HOST_IP]" 
  echo "   Ex: ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 node-01 192.168.100.34"
  echo "   or"
  echo "   Ex: ./deploy-consensus.sh beacon-01 v1.12.2 HEAD-09d761 8658 1 node-01"
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
echo " If you have any *.p2p file from another consensus node inside ./peers "
echo "   directory, you can edit this file and add as many '--peer=' option"
echo "   as you have <CONSENSUS_NODE>.p2p files in docker run command here." 
echo ""
echo " I hope the execution container is already running at http://$6:8551 ... " 
echo ""
read -p "Press any key to continue... " -n1 -s

NODE_NAME=$(pwd)/$1
GETH_VERSION=$2
PRYSM_VERSION=$3
NETWORK_ID=$4
NODE_INDEX=$5
EXECUTION_NODE=$6
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
    echo "JWT Token does not exist."
    echo "  Make sure you have a Execution Container deployed here."
    exit 1
fi
cp ${JWT_FILE} ${CONSENSUS}

NODE_KEY_FILE="${CONSENSUS}/priv.key"
echo "Generating P2P Private Key..."
openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout > keypair
cat keypair | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//' > ${NODE_KEY_FILE}
rm -rf priv && rm -rf keypair


echo "Deploying Beacon $1"

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

docker stop $1 && docker rm $1

docker run --name=$1 --hostname=$1 \
--network=interna \
-v ${CONSENSUS}:/consensus \
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
--execution-endpoint=http://${EXECUTION_NODE}:8551 \
--accept-terms-of-use \
--jwt-secret=/consensus/jwtsecret \
--disable-staking-contract-check \
--enable-debug-rpc-endpoints \
--interop-eth1data-votes=true \
--p2p-priv-key=/consensus/priv.key
# --peer value
# --peer value

echo "Waiting to beacon brings up..."
sleep 15

echo "Taking ENODE address..."

if [ ! -d "./peers" ]; then
  mkdir ./peers
fi

rm -f ./peers/$1.p2p

P2P_API=("http://localhost:$RPC_PORT/p2p")

curl \
${P2P_API} | awk -F/tcp '{print "/tcp" $NF}' | grep p2p > ./peers/$1.temp

P2P_ADDRESS=$(head -1 ./peers/$1.temp)
temp=("/ip4/"${HOST_IP}${P2P_ADDRESS})

P2P_EXTERNAL=${temp/13000/"$P2P_TCP"}

echo ${P2P_EXTERNAL} > ./peers/$1.p2p

rm -f ./peers/$1.temp

echo ""
echo "Done! You may want to save the ./peers directory"
echo "  contents to put it in another host and allow them to sync."