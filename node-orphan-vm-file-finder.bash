#!/bin/bash
set -e
ANK_IN_USE=()
ORPHANED_FILES=()
ERRORED_FILES=()
VM_LIB=$(anka config vm_lib_dir)
IMG_LIB=$(anka config img_lib_dir)
STATE_LIB=$(anka config state_lib_dir)
ANKA_IMAGE_BINARY="/Library/Application Support/Veertu/Anka/bin/anka_image"
function recurse_ank_layers() {
	local ANK_DIR=$1
	local ANK_FILE=$2
	echo "Adding: $ANK_FILE"
	ANK_IN_USE+=( "$ANK_FILE" )
  if "$ANKA_IMAGE_BINARY" info "${ANK_DIR}$ANK_FILE" 1>/dev/null; then
    while true; do
      FOUNDATION_ANK_FILE=$("$ANKA_IMAGE_BINARY" info "${ANK_DIR}$ANK_FILE" | grep 'Base Image:' | awk -F: '{ print $NF }' | xargs)
      if [ "$FOUNDATION_ANK_FILE" == "" ]; then
        break
      fi
      recurse_ank_layers "$ANK_DIR" "$FOUNDATION_ANK_FILE"
      break
    done
  else
    ERRORED_FILES+=( "${ANK_DIR}$ANK_FILE" )
  fi
}
IFS=$'\n'
for YAML_FILE in $(find "$VM_LIB" -name '*.yaml'); do
	echo "Searching $YAML_FILE..."
	# FOUND_PATH="$(echo "$YAML_FILE" | rev | cut -d/ -f2-99 | rev)"
	IMG_ANK=$(grep -E "^ +file:.*.ank" "$YAML_FILE" | grep '.ank' | awk '{ print $NF }' || true)
	STATE_ANK=$(grep -E "state_file:.*.ank" "$YAML_FILE" | grep '.ank' | awk '{ print $NF }' || true)
	if [[ "$IMG_ANK" != "" ]]; then
		recurse_ank_layers "$IMG_LIB" "$IMG_ANK"
	fi
	if [[ "$STATE_ANK" != "" ]]; then
		recurse_ank_layers "$STATE_LIB" "$STATE_ANK"
	fi
done
echo "ORPHANS =========================================="
FILE_ARRAY=($(find "$IMG_LIB" \( -name '*.ank' -o -name '*.ank.*' \) -type f))
FILE_ARRAY+=($(find "$STATE_LIB" \( -name '*.ank' -o -name '*.ank.*' \) -type f))
for ANK_FILE in "${FILE_ARRAY[@]}"; do
	if [[ ! "${ANK_IN_USE[@]}" =~ $(basename "$ANK_FILE") ]]; then
		echo "$ANK_FILE"
	# else
	# 	echo "$ANK_FILE - REFERENCED"
	fi
done
echo "=========================================="
for ANK_FILE in "${ERRORED_FILES[@]}"; do
		echo "$ANK_FILE - ERRORED"
done
IFS=
