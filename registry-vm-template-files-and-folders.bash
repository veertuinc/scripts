#!/bin/bash
set -eo pipefail
IFS=$'\n'
[[ -z "$1" ]] && echo "must provide root registry data dir as first arg..." && exit 1
[[ -z "$2" ]] && echo "must provide VM UUID and second arg..." && exit 2
pushd $1 &>/dev/null
IMAGES=($(cat ./vm_dir/$2/*/images | sort | uniq))
STATE_FILES+=($(grep -hn "^state_file: " ./vm_dir/$2/*/*.yaml | cut -d" " -f2 | sort | uniq))
RELATED_ITEMS=( "./vm_dir/$2" )
for file in ${IMAGES[@]}; do
  if ls ./images_dir/$file 1>/dev/null; then
    RELATED_ITEMS+=( "./images_dir/$file" )
  fi
done
for file in ${STATE_FILES[@]}; do
  if ls ./state_file_dir/$file 1>/dev/null; then
    RELATED_ITEMS+=( "./state_file_dir/$file" )
  fi
done
echo "list of orphaned .ank ============================="
for item in "${RELATED_ITEMS[@]}"; do
  echo $item
done
IFS=
popd &>/dev/null