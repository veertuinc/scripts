#!/bin/bash
set -eo pipefail
DIAG_FOLDER_NAME="anka-node-diagnostics"
DIAG_PATH="/tmp/${DIAG_FOLDER_NAME}"
echo "] Collecting Diagnostics from current machine (Please be patient)"

cleanup() {
  sudo rm -rf "${DIAG_PATH}"
}

execute() {
  FILE_NAME="${2:-$1}"
  FILE_NAME="${FILE_NAME// /_}"
  FILE_NAME="${FILE_NAME//\//\\}"
  FILE_NAME="${FILE_NAME//sudo_/}"
  ( eval "${1}" ) >> "${FILE_NAME}"
}

execute-multiple-times() {
  TIMES="${2:-5}"
  COMMAND=$(echo "${1}" | xargs)
  COUNT=0
  while [ "${COUNT}" -le "${TIMES}" ]; do
    execute "echo \"= $COUNT ========================================\"; ${COMMAND}" "${COMMAND}"
    sleep 1
    COUNT=$((COUNT+1))
  done
}

copy-files-from-dir() {
  OLD_IFS=$IFS
  IFS=$'\n'
  DIR="${1}"
  FILTER="${2:-"*"}"
  DIR_LOCAL="$(echo ${DIR} | cut -d/ -f2-99)"
  sudo -n -i bash -c "mkdir -p \"${DIAG_PATH}/${DIR_LOCAL}\""
  for FULL_FILE_PATH in $(sudo -n -i bash -c "ls -t \"${DIR}\"/${FILTER}" 2>/dev/null | head -15); do
    sudo -n -i bash -c "cp -f \"${FULL_FILE_PATH}\" \"${DIAG_PATH}/${DIR_LOCAL}\""
  done
  IFS=$OLD_IFS
}

copy-folders-from-dir() {
  OLD_IFS=$IFS
  IFS=$'\n'
  DIR="${1}"
  DIR_LOCAL="$(echo ${DIR} | cut -d/ -f2-99)"
  sudo -n -i bash -c "mkdir -p \"${DIAG_PATH}/${DIR_LOCAL}\""
  for FULL_FOLDER_PATH in $(sudo -n -i bash -c "ls -d \"${DIR}\"/* 2>/dev/null"); do
    sudo -n -i bash -c "cp -rf \"${FULL_FOLDER_PATH}\" \"${DIAG_PATH}/${DIR_LOCAL}\""
  done
  IFS=$OLD_IFS
}

echo "]] INFO: This script will perform some commands as root."
sudo echo ""
# trap cleanup EXIT
CURRENT_USER="${USER}"
[[ $CURRENT_USER == root ]] && CURRENT_USER=
for CUSER in $CURRENT_USER root; do
  mkdir -p "${DIAG_PATH}/${CUSER}"
  [[ "${CUSER}" == root ]] && SUDO="sudo "
  pushd "${DIAG_PATH}/${CUSER}" &>/dev/null
    execute "${SUDO}anka version" &
    execute "${SUDO}ankacluster --version" &
    execute "${SUDO}ankacluster status" &
    execute "${SUDO}anka list" &
    if [[ $(${SUDO}anka list | grep -c "|") -gt 0 ]]; then
      for TEMPLATE in $(${SUDO}anka list | grep "|" | grep -v uuid | awk '{print $2}'); do
        execute "${SUDO}anka show ${TEMPLATE}" &
        execute "${SUDO}anka describe ${TEMPLATE}" &
      done
    fi
    execute "${SUDO}anka config" &
    execute-multiple-times "${SUDO}df -h" &
    execute "${SUDO}ls -laht" &
    execute "${SUDO}sw_vers" &
    execute "${SUDO}system_profiler SPHardwareDataType" &
    execute "${SUDO}sysctl -a" &
    execute-multiple-times "${SUDO}iostat" &
    execute-multiple-times "${SUDO}vm_stat" &
    execute "${SUDO}diskutil list" &
    execute "${SUDO}ifconfig" &
    execute-multiple-times "${SUDO}nettop -l 1" &
    execute-multiple-times "${SUDO}ps -axro pcpu | awk \'{sum+=\$1} END {print sum}\'" & # This is a per-core CPU metric, so on a 12 core CPU you can get up to 1200; you're not capped at 100.
    copy-files-from-dir "$($SUDO anka config log_dir)" &
    execute "${SUDO}ls -laht \"$($SUDO anka config vm_lib_dir)\"" &
    execute "${SUDO}ls -laht \"$($SUDO anka config img_lib_dir)\"" &
    execute "${SUDO}ls -laht \"$($SUDO anka config state_lib_dir)\"" &
    if [[ "${CUSER}" == root ]]; then
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "system.log*" &
      execute "${SUDO}ps aux | grep anka" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "anka*.diag" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "anka*.crash" &
      copy-files-from-dir "/var/log/veertu" "anka_agent.*" &
      execute-multiple-times "${SUDO}fs_usage -f diskio -t 2" 3 & # https://superuser.com/a/1542670
      wait $!
      execute-multiple-times "${SUDO}fs_usage -w -t 1" &
      copy-folders-from-dir "$($SUDO anka config vm_lib_dir)" &
    else
      copy-folders-from-dir "$($SUDO anka config vm_lib_dir)" &
    fi
    wait
  popd &>/dev/null
done
TAR_NAME="anka-node-diagnostics.tar.gz"
pushd /tmp/ &>/dev/null
  tar -czvf $TAR_NAME $DIAG_FOLDER_NAME &>/dev/null
popd
mv /tmp/$TAR_NAME .
echo "]] Created $TAR_NAME"
ls -l $TAR_NAME