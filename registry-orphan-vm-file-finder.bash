#!/bin/bash
set -eo pipefail
IFS=$'\n'
LIST_OF_IN_USE_ANK=($(cat /Library/Application\ Support/Veertu/Anka/registry/vm_dir/*/*/images | sort | uniq))
LIST_OF_IN_USE_ANK+=($(grep -hn "^state_file: " /Library/Application\ Support/Veertu/Anka/registry/vm_dir/*/*/*.yaml | cut -d" " -f2 | sort | uniq))
ALL_ANK_FILES=($(find /Library/Application\ Support/Veertu/Anka/registry -name "*.ank" | sed -E 's/[[:space:]]/\\\ /g'))
ANK_FILES_TO_DELETE=($(find /Library/Application\ Support/Veertu/Anka/registry -name "*.ank"| sed 's/\/Library\/Application Support\/Veertu\/Anka\/registry//g'))
for in_use_ank in ${LIST_OF_IN_USE_ANK[@]}; do
	for ank in ${ALL_ANK_FILES[@]}; do
    ank="$(echo $ank | sed 's/\/Library\/Application\\ Support\/Veertu\/Anka\/registry//g')"
	  if [[ "$ank" =~ $in_use_ank ]]; then
	  	ANK_FILES_TO_DELETE=( "${ANK_FILES_TO_DELETE[@]/$ank}" )
	  	break
	  fi
	done
done
echo "list of orphaned .ank ============================="
echo "${ANK_FILES_TO_DELETE[@]}" | xargs
IFS=
