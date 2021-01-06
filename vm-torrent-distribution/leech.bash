#!/bin/bash
set -exo pipefail
SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)
cd $SCRIPT_DIR
cleanup() {
  ssh-run ""
  # ssh-run "rm -f /tmp/leecher-$ID.yaml"
}
ssh-run() {
  ssh $SSH_KEY $REMOTE_NODE bash -lc "'$@'"
}
[[ ! -z $SSH_KEY ]] && SSH_KEY="-i $SSH_KEY"
[[ -z "$1" ]] && echo "You must provide a torrent file (\$1)!" && exit 1
[[ ! "$1" =~ \.torrent ]] && echo "You must provide a .torrent file (\$1)!" && exit 2
[[ ! "$1" =~ ^/ ]] && echo "You must provide an absolute path to a torrent file (\$1)!" && exit 3
[[ -z "$2" ]] && echo "You must provide a remote server to start the download on (include {user}@ if needed) (\$2)!" && exit 4
[[ -z "$3" ]] && echo "You must provide the peer IPs that will be used to seed the torrent!" && exit 5
TORRENT_FILE=$1
REMOTE_NODE=$2
RPCPORT=${RPCPORT:-"7247"}
echo "] rsyncing to node $REMOTE_NODE"
rsync -e "ssh $SSH_KEY -o StrictHostKeyChecking=no" -avzP $TORRENT_FILE $REMOTE_NODE:/tmp
[[ -z "$(ssh-run "command -v anka")" ]] && echo "Ensure anka is installed on the destination machine!" && exit 6 
REMOTE_NODE_VM_TEMPLATE_ROOT_DIR_ONE_UP=$(ssh-run "anka config vm_lib_dir | rev | cut -d/ -f4-99 | rev")
ID=$RANDOM
if [[ -z "$(ssh-run "ps aux | grep \"[r]ain server\"")" ]]; then
  LEECHER_YAML="/tmp/leecher-$ID.yaml"
  echo "] rain server not found... starting server"
ssh-run "
cat << EOF > $LEECHER_YAML
datadir: $REMOTE_NODE_VM_TEMPLATE_ROOT_DIR_ONE_UP
database: leecher.db
datadirincludestorrentid: false
rpcport: $RPCPORT
dhtenabled: false
EOF"
  ssh-run "cat $LEECHER_YAML"
  ssh-run "nohup rain server --config $LEECHER_YAML &>/tmp/leecher-$ID.log &"
else
  LEECHER_YAML=$(ssh-run "ps aux | grep "[r]ain server --config leecher" | rev | awk \"{print \$1}\" | rev")
  # EXISTING_SERVER_ID=$(echo $LEECHER_YAML | cut -d- -f2 | cut -d. -f1)
  echo "] rain server already running... using existing server"
fi

ssh-run "rain client --url http://127.0.0.1:$RPCPORT add --torrent $TORRENT_FILE --id $ID"

ssh-run "rain client --url http://127.0.0.1:$RPCPORT add-peer --addr 127.0.0.1:50000 --id $ID"