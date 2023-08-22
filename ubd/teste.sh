#!/bin/bash

for entry in ./peers/*.p2p
do
   P2P_ADDRESS=$(head -1 $entry)
   if [[ $P2P_ADDRESS == *"/ip4/"* ]]; then
     IFS='/' read -r -a ARRAY_ADDRESS <<< "$P2P_ADDRESS"
     PORTA_RPC=${ARRAY_ADDRESS[0]}
     PEER=/${ARRAY_ADDRESS[1]}/${ARRAY_ADDRESS[2]}/${ARRAY_ADDRESS[3]}/${ARRAY_ADDRESS[4]}/${ARRAY_ADDRESS[5]}/${ARRAY_ADDRESS[6]}
     REMOTE_IP=${ARRAY_ADDRESS[2]}
     URL="http://"${REMOTE_IP}:${PORTA_RPC}"/prysm/node/trusted_peers"
     DATA=" {\"addr\":\""${PEER}"\"}"
     echo "Porta: ${PORTA_RPC}"
     echo "IP: ${REMOTE_IP}"
     echo $PEER
     echo ${URL}
     echo ${DATA}
     curl \
	     ${URL} \
	     -X POST \
	     -H "Content-Type: application/json" \
	     -d ${DATA}	
   fi
done


