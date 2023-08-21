echo ""
echo ""
echo ""
echo "*********************************"
echo "|           PEER SYNC           |"
echo "*********************************"
echo "Will register all enodes in 'peers' folder"
echo ""

if [ "$#" -lt 1 ]
then
  echo "Use: ./addpeers.sh <EXTERNAL_RPC_PORT>"
  echo "   Ex: ./addpeers.sh 35100"
  exit 1
fi

echo "Registering another peers..."

RPC_PORT=$1

search_dir=./peers
for entry in "$search_dir"/*.enode
do
  echo "$entry"
  curl -X POST http://localhost:${RPC_PORT} --header 'Content-Type: application/json' -d @$entry
done


