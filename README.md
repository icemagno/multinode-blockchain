# Multinode Private Blockchain
A tree nodes private blockchain

![screen](https://github.com/icemagno/multinode-blockchain/assets/4127512/17f6a140-c45a-4a65-bba9-ad5b892bf5a2)

## Featuring
* All Docker
* Capella full PoS enabled already
* A Grafana panel
* Three Execution Nodes
* Three Consensus Nodes
* Three Validator Nodes with about 22 validators each ( 22 + 22 + 20 = total 64 )
* Local peers syncing for Executions and Beacons
* No need validators to stake 32 ETH
* Already created some accounts
* A lot of ETH to distribute
* Postman JSON file to test endpoints
* A hit-and-run script file (terraform.sh)
* Easy to customize
  
  ![eth](https://github.com/icemagno/multinode-blockchain/assets/4127512/35758a7a-ac34-4a89-bccb-5b38c02722db)

## Exposed ports

The ports will follow the convention:

```35xYY```

where 
```
X   = node number
YY  = port ID
```
Port ID:

```
	> 00 = 8545
	> 01 = 8546
	> 02 = 8551
	> 03 = 30303
	> 04 = 12000
	> 05 = 13000
	> 06 = 3500
	> 07 = 4000
	> 08 = 8080 
```

A port 35305 will be mapped to the port 13000 ( execution P2P TCP) of the node 03 

![portainer](https://github.com/icemagno/multinode-blockchain/assets/4127512/99b6a2a7-9652-4fe4-b4ed-52c99ad5d9e5)
![portainer2](https://github.com/icemagno/multinode-blockchain/assets/4127512/33a65426-4497-48fe-803d-2d9e3ce5ac34)
