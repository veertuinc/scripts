#!/bin/bash
set -exo pipefail
[[ -z "$1" ]] && echo "You must provide a VM Template name!" && exit 1
SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)
cd $SCRIPT_DIR
TEMPLATE_NAME=$1
[[ -z "$2" ]] && echo "Please specify a comma separated list of nodes that will be leeching the VM template!" && exit 2
LEECHERS="$2"
seeder-cleanup() {
  TORRENT_ID=$(rain client list | jq -r ".[] | select(.Name==\"$TORRENT_NAME\") | .ID")
  rain client remove --id $TORRENT_ID || true
  kill -15 $(ps aux | grep "$TEMPLATE_NAME-[s]eeder" | awk "{print \$2}")
}
TORRENT_NAME=${TORRENT_NAME-"Anka"}
FILE_AND_FOLDER_LIST="$(../collect-vm-template-files-and-folders.bash $TEMPLATE_NAME)"
OLD_IFS=$IFS
IFS=$'\n'
# echo "${FILE_AND_FOLDER_LIST[@]}"
# FILES_STRING=""
# for ITEM in ${FILE_AND_FOLDER_LIST[@]}; do
#   PARTIAL_PATH="$(echo $ITEM | rev | cut -d/ -f1-3 | rev)"
#   FILES_STRING="$FILES_STRING --file $PARTIAL_PATH"
# done
# # VM_TEMPLATE_ROOT_DIR=$(anka config vm_lib_dir | rev | cut -d/ -f3-99 | rev)
# VM_TEMPLATE_ROOT_DIR_ONE_UP=$(anka config vm_lib_dir | rev | cut -d/ -f4-99 | rev)
# VM_TEMPLATE_ROOT_DIR_END=$(anka config vm_lib_dir | rev | cut -d/ -f3 | rev)
# pushd "$VM_TEMPLATE_ROOT_DIR_ONE_UP"
# rm -f /tmp/$TORRENT_NAME.torrent && eval "rain torrent create --name $VM_TEMPLATE_ROOT_DIR_END --out /tmp/$TORRENT_NAME.torrent --root $VM_TEMPLATE_ROOT_DIR_END $FILES_STRING"
cd /tmp
SEEDER_RPCPORT=${SEEDER_RPCPORT:-"7246"}
# cat << EOF > $TEMPLATE_NAME-seeder.yaml
# datadir: $VM_TEMPLATE_ROOT_DIR_ONE_UP
# database: seeder.db
# datadirincludestorrentid: false
# rpcport: $SEEDER_RPCPORT
# dhtenabled: false
# portbegin: 50000
# portend: 50001
# EOF
# trap seeder-cleanup 0
# rain server --config $TEMPLATE_NAME-seeder.yaml &>$TEMPLATE_NAME-seeder.log &
# sleep 5
# rain client add --torrent $TORRENT_NAME.torrent

# LEECHERS
IFS=","
ssh-run() {
  DESTINATION="$1"
  shift
  eval ssh $SSH_KEY $DESTINATION bash -lc \"\'$@\'\"
}
leecher-cleanup() {
  for LEECHER in $LEECHERS; do
    ssh-run $LEECHER "rm -f $LEECHER_YAML"
    ssh-run $LEECHER "rm -f /tmp/$TORRENT_NAME.torrent"
  done
}
[[ ! -z $SSH_KEY ]] && SSH_KEY="-i $SSH_KEY"
LEECH_RPCPORT=${LEECH_RPCPORT:-"7247"}
ID=$RANDOM
LEECHER_YAML="/tmp/leecher-$ID.yaml"
LEECHER_TORRENT="/tmp/$TORRENT_NAME.torrent"
trap leecher-cleanup 0
for LEECHER in $LEECHERS; do
  rsync -avzP -e "ssh $SSH_KEY -o StrictHostKeyChecking=no" $TORRENT_NAME.torrent $LEECHER:$LEECHER_TORRENT
  [[ -z "$(ssh-run $LEECHER "command -v anka")" ]] && echo "Ensure anka is installed on the destination machine!" && exit 6 
  LEECHER_NODE_VM_TEMPLATE_ROOT_DIR_ONE_UP=$(ssh-run $LEECHER "anka config vm_lib_dir | rev | cut -d/ -f4-99 | rev")
  # if [[ -z "$(ssh-run $LEECHER "ps aux | grep \"[r]ain server\"")" ]]; then
  #   echo "] rain server not found... starting server"
ssh-run $LEECHER "
cat << EOF > $LEECHER_YAML
datadir: $LEECHER_NODE_VM_TEMPLATE_ROOT_DIR_ONE_UP
database: leecher.db
datadirincludestorrentid: false
rpcport: $LEECH_RPCPORT
dhtenabled: false
EOF"
    ssh-run $LEECHER "cat $LEECHER_YAML"
  #   ssh-run $LEECHER "nohup rain server --config $LEECHER_YAML &>/tmp/leecher-$ID.log &"
  # else
  #   LEECHER_YAML=$(ssh-run $LEECHER "ps aux | grep "[r]ain server --config leecher" | rev | awk \"{print \$1}\" | rev")
  #   # EXISTING_SERVER_ID=$(echo $LEECHER_YAML | cut -d- -f2 | cut -d. -f1)
  #   echo "] rain server already running... using existing server"
  # fi

  # ssh-run $LEECHER "rain client --url http://127.0.0.1:$SEEDER_RPCPORT add --torrent $TORRENT_FILE --id $ID"
  # ssh-run $LEECHER "rain client --url http://127.0.0.1:$SEEDER_RPCPORT add-peer --addr 127.0.0.1:50000 --id $ID"
done
while true; do
  read -p 'Hit enter to show torrent distribution statuses...' blah
  echo "YES!"
  for LEECHER in $LEECHERS; do
    ssh-run $LEECHER ""
  done
done

IFS=$OLD_IFS
