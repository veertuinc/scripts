#!/bin/bash
set -eo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
IFS=$'\n'
[[ -z "$1" ]] && echo "must provide root registry data dir as first arg..." && exit 1
pushd $1 &>/dev/null
IMAGES=($(cat ./vm_dir/*/*/images | sort | uniq || true))
STATE_FILES+=($(cat ./vm_dir/*/*/state_files | sort | uniq || true))
for file in ${IMAGES[@]}; do
  $SCRIPT_DIR/bin/anka_image info "${1}images_dir/$file" 1>/dev/null
done
for file in ${STATE_FILES[@]}; do
    $SCRIPT_DIR/bin/anka_image info "${1}state_file_dir/$file" 1>/dev/null
done
IFS=
popd &>/dev/null

echo "No output above = No corruption found"