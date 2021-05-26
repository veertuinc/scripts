#!/bin/bash
set -eo pipefail
IFS=$'\n'
[[ -z "$1" ]] && echo "must provide root registry data dir as first arg..." && exit 1
[[ ! "$1" =~ ^/.*/$ ]] && echo "must start and end with / (be a valid path + ending in /)" && exit 2
pushd $1 &>/dev/null
if [[ ! -z "$(ls -A "${1}vm_dir/" 2>/dev/null)" ]]; then
  LIST_OF_IN_USE_ANK=($(cat ./vm_dir/*/*/images | sort | uniq))
  LIST_OF_IN_USE_ANK+=($(cat ./vm_dir/*/*/state_files | sort | uniq))
  ALL_ANK_FILES=($(find . -name "*.ank" | sed -E 's/[[:space:]]/\\\ /g'))
  ANK_FILES_TO_DELETE=($(find . -name "*.ank"))
  for in_use_ank in ${LIST_OF_IN_USE_ANK[@]}; do
    for ank in ${ALL_ANK_FILES[@]}; do
      if [[ "$ank" =~ $in_use_ank ]]; then
        ANK_FILES_TO_DELETE=( "${ANK_FILES_TO_DELETE[@]/$ank}" )
        break
      fi
    done
  done
  echo "${ANK_FILES_TO_DELETE[@]}" | xargs
else # vm_dir is empty
  ANK_FILES_TO_DELETE=($(find . -name "*.ank" | sed -E 's/[[:space:]]/\\\ /g'))
  echo "${ANK_FILES_TO_DELETE[@]}" | xargs
fi
IFS=
popd &>/dev/null
