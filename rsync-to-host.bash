#!/bin/bash
set -eo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPT_DIR
[[ -z "$1" ]] && echo "You must provide a VM Template name as ARG1!" && exit 1
[[ -z "$2" || ! "$2" =~ @ ]] && echo "You must provide the user@host to rsync the files to as ARG2!" && exit 2
[[ -z "$3" || ! "$3" =~ ^/ ]] && echo "You must provide the absolute path to a SSH private key to use when accessing destination host as ARG3!" && exit 3
TEMPLATE="$1"
REMOTE_USER_AND_IP="$2"
REMOTE_SSH_PRIV_KEY="$3"
COLLECT_RESULTS="$(./collect-vm-template-files-and-folders.bash $TEMPLATE)"
pushd "$(anka config vm_lib_dir)/.." && SOURCE_BASE_PATH=$(pwd)
oldIFS=$IFS;
IFS=$'\n';
for COLLECT_PATH in ${COLLECT_RESULTS[*]}; do
  SOURCE_FILE="$COLLECT_PATH"
  SOURCE_SHORT_PATH=$(echo $SOURCE_FILE | sed "s/$(echo $SOURCE_BASE_PATH | sed 's/\//\\\//g')\///g")
  rsyncOpts=""
  DESTINATION_STORAGE_LOCATION=$(ssh -o StrictHostKeyChecking=no -i "$REMOTE_SSH_PRIV_KEY" $REMOTE_USER_AND_IP "cd \"\$(/usr/local/bin/anka config vm_lib_dir)/..\" && pwd")
  DESTINATION_STORAGE_LOCATION=${DESTINATION_STORAGE_LOCATION// /\\ }
  ssh -o StrictHostKeyChecking=no -i "$REMOTE_SSH_PRIV_KEY" $REMOTE_USER_AND_IP "mkdir -p $DESTINATION_STORAGE_LOCATION/$(echo ${SOURCE_SHORT_PATH// /\\ } | rev | cut -d/ -f2-99 | rev)"
  if [[ -d "$SOURCE_STORAGE_LOCATION" ]]; then 
    rsyncOpts="--recursive"
  fi
  echo rsync -avzP $rsyncOpts -e "ssh -i $REMOTE_SSH_PRIV_KEY -o StrictHostKeyChecking=no" "$SOURCE_FILE" ${REMOTE_USER_AND_IP}:${DESTINATION_STORAGE_LOCATION}/${SOURCE_SHORT_PATH}
  rsync -avzP $rsyncOpts -e "ssh -i $REMOTE_SSH_PRIV_KEY -o StrictHostKeyChecking=no" "$SOURCE_FILE" ${REMOTE_USER_AND_IP}:${DESTINATION_STORAGE_LOCATION}/${SOURCE_SHORT_PATH}
done; 
IFS=$oldIFS
popd