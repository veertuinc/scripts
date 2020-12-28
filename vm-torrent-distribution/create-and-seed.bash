#!/bin/bash
set -exo pipefail
[[ -z "$1" ]] && echo "You must provide a VM Template name!" && exit 1
SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)
cd $SCRIPT_DIR
TEMPLATE_NAME=$1
TORRENT_NAME=${TORRENT_NAME-"Anka"}
cleanup() {
  TORRENT_ID=$(rain client list | jq ".[] | select(.Name==\"$TORRENT_NAME\") | .ID")
  rain client remove --id $TORRENT_ID || true
  kill -15 $(ps aux |grep "$TEMPLATE_NAME-[s]eeder" | awk "{print \$2}")
}
FILE_AND_FOLDER_LIST="$(../collect-vm-template-files-and-folders.bash $TEMPLATE_NAME)"
OLD_IFS=$IFS
IFS=$'\n'
# echo "${FILE_AND_FOLDER_LIST[@]}"
FILES_STRING=""
for ITEM in ${FILE_AND_FOLDER_LIST[@]}; do
  PARTIAL_PATH="$(echo $ITEM | rev | cut -d/ -f1-3 | rev)"
  FILES_STRING="$FILES_STRING --file $PARTIAL_PATH"
done
# VM_TEMPLATE_ROOT_DIR=$(anka config vm_lib_dir | rev | cut -d/ -f3-99 | rev)
VM_TEMPLATE_ROOT_DIR_ONE_UP=$(anka config vm_lib_dir | rev | cut -d/ -f4-99 | rev)
VM_TEMPLATE_ROOT_DIR_END=$(anka config vm_lib_dir | rev | cut -d/ -f3 | rev)
pushd "$VM_TEMPLATE_ROOT_DIR_ONE_UP"
rm -f /tmp/$TORRENT_NAME.torrent && eval "rain torrent create --name $VM_TEMPLATE_ROOT_DIR_END --out /tmp/$TORRENT_NAME.torrent --root $VM_TEMPLATE_ROOT_DIR_END $FILES_STRING"
cd /tmp
cat << EOF > $TEMPLATE_NAME-seeder.yaml
datadir: $VM_TEMPLATE_ROOT_DIR_ONE_UP
database: seeder.db
datadirincludestorrentid: false
rpcport: 7246
dhtenabled: false
portbegin: 50000
portend: 50001
EOF
trap cleanup 0
rain server --config $TEMPLATE_NAME-seeder.yaml &>$TEMPLATE_NAME-seeder.log &
sleep 5
rain client add --torrent $TORRENT_NAME.torrent
tail -f $TEMPLATE_NAME-seeder.log
IFS=$OLD_IFS
