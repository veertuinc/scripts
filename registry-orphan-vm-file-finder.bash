#!/bin/bash
set -eo pipefail
IFS=$'\n'
[[ -z "$1" ]] && echo "must provide root registry data dir as first arg..." && exit 1
pushd $1
LIST_OF_IN_USE_ANK=($(cat ./vm_dir/*/*/images | sort | uniq))
LIST_OF_IN_USE_ANK+=($(grep -hn "^state_file: " ./vm_dir/*/*/*.yaml | cut -d" " -f2 | sort | uniq))
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
echo "list of orphaned .ank ============================="
echo "${ANK_FILES_TO_DELETE[@]}" | xargs
IFS=
popd &>/dev/null