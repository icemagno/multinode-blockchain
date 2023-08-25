#!/bin/bash



echo "Registering peers..."
search_dir=./peers
for entry in "$search_dir"/*.p2p
do
    P2P_ADDRESS=$(head -1 $entry)
    temp=`cat $entry | jq -r '.addr'`
    RPC_PORT=`cat $entry | jq -r '.rpc'`

    if [[ $P2P_ADDRESS == *"/ip4/"* ]]; then
        IFS='/' read -r -a ARRAY_ADDRESS <<< "$P2P_ADDRESS"
        PEER=/${ARRAY_ADDRESS[1]}/${ARRAY_ADDRESS[2]}/${ARRAY_ADDRESS[3]}/${ARRAY_ADDRESS[4]}/${ARRAY_ADDRESS[5]}/${ARRAY_ADDRESS[6]}
        REMOTE_IP=${ARRAY_ADDRESS[2]}
        URL="http://"${REMOTE_IP}:${RPC_PORT}"/prysm/node/trusted_peers"

        echo "To "$URL
        for entry2 in "$search_dir"/*.p2p
        do
            if [[ $entry != $entry2 ]]; then
                P2P_DATA=$(head -1 $entry2)
                if [[ $P2P_DATA == *"/ip4/"* ]]; then
                    echo "  > "$P2P_DATA
                    curl ${URL} -X POST -H "Content-Type: application/json" -d ${P2P_DATA}
                fi
            fi
        done
   fi
done
