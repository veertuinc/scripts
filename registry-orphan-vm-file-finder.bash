#!/bin/bash
set -eo pipefail
LIST_OF_IN_USE_ANK=($(cat /Library/Application\ Support/Veertu/Anka/registry/vm_dir/*/*/images | uniq))
ALL_ANK_FILES=($(ls -a /Library/Application\ Support/Veertu/Anka/registry/images_dir | grep -e '^\.*$' -v))
ANK_FILES_TO_DELETE=($(ls -a /Library/Application\ Support/Veertu/Anka/registry/images_dir | grep -e '^\.*$' -v))
for in_use_ank in "${LIST_OF_IN_USE_ANK[@]}"; do
	#echo $in_use_ank
	for images_dir_ank in "${ALL_ANK_FILES[@]}"; do
	  if [[ "$images_dir_ank" == "$in_use_ank" ]]; then
	  	ANK_FILES_TO_DELETE=( "${ANK_FILES_TO_DELETE[@]/$images_dir_ank}" )
	  	break
	  fi
	done
done
echo "list of orphaned .ank ============================="
echo "${ANK_FILES_TO_DELETE[@]}"


