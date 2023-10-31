#!/bin/bash
set -eo pipefail
VERBOSE=${VERBOSE:-false}
[[ -z "$1" ]] && echo "You must provide a VM Template name!" && exit 1
TEMPLATE_UUID=$(anka list | grep "$1 " | awk -F"|" '{print $3}' | xargs)
IN_USE=()
VM_LIB=$(anka config vm_lib_dir)
[[ "$VM_LIB" =~ /$ ]] || VM_LIB="$VM_LIB/"
IMG_LIB=$(anka config img_lib_dir)
[[ "$IMG_LIB" =~ /$ ]] || IMG_LIB="$IMG_LIB/"
STATE_LIB=$(anka config state_lib_dir)
[[ "$STATE_LIB" =~ /$ ]] || STATE_LIB="$STATE_LIB/"
TEMPLATE_PATH="${VM_LIB}$TEMPLATE_UUID"
ANKA_IMAGE_BINARY="/Library/Application Support/Veertu/Anka/bin/anka_image"

function recurse_ank_layers() {
  local ANK_DIR=$1
  local ANK_FILE=$2
  $VERBOSE && echo "Adding: $ANK_FILE"
  IN_USE+=( "${ANK_DIR}$ANK_FILE" )
  while true; do
    FOUNDATION_ANK_FILE=$("$ANKA_IMAGE_BINARY" info "${ANK_DIR}$ANK_FILE" | grep 'Base Image:' | awk -F: '{ print $NF }' | xargs || true)
    [ "$FOUNDATION_ANK_FILE" == "" ] && break || true
    recurse_ank_layers "$ANK_DIR" "$FOUNDATION_ANK_FILE"
    break
  done
}

IFS=$'\n'
for YAML_FILE in $(find "${VM_LIB}$TEMPLATE_UUID" -name '*.yaml'); do
  unset IMG_ANK
  unset STATE_ANK
  $VERBOSE && echo "Searching $YAML_FILE..."
  # FOUND_PATH="$(echo "$YAML_FILE" | rev | cut -d/ -f2-99 | rev)"
  IMG_ANK=$(grep -E "file:.*.ank" "$YAML_FILE" | grep '.ank' | awk '{ print $NF }' || true)
  STATE_ANK=$(grep -E "state_file:.*.ank" "$YAML_FILE" | grep '.ank' | awk '{ print $NF }' || true)
  if [ "$IMG_ANK" != "" ]; then
    recurse_ank_layers "$IMG_LIB" "$IMG_ANK"
  fi
  if [ "$STATE_ANK" != "" ]; then
    recurse_ank_layers "$STATE_LIB" "$STATE_ANK"
  fi
done
IFS=
$VERBOSE && echo "================================"
for item in "${IN_USE[@]}"; do
  echo "$item"
done
# Template path must be copied last or else the template/tag will show up on the node and there won't be able layers on disk
echo "${TEMPLATE_PATH}"
