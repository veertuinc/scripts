#!/bin/bash
set -eo pipefail
[[ -z "$1" ]] && echo "You must provide a VM Template name!" && exit 1
TEMPLATE_NAME=$1
FILE_AND_FOLDER_LIST="$(./collect-vm-template-files-and-folders.bash $TEMPLATE_NAME)"
IFS=$'\n'
FILE_ARGS="create"
echo "${FILE_AND_FOLDER_LIST[@]}"

# TODO: create torrent for each file and folder in list
IFS=
