#!/usr/bin/env bash
set -eo pipefail
UNIQUENESS="$(whoami | cut -d' ' -f1)"
DIAG_FOLDER_NAME="anka-node-diagnostics-${UNIQUENESS}"
TEMP_STORAGE_PATH="/tmp"
DIAG_PATH="${TEMP_STORAGE_PATH}/${DIAG_FOLDER_NAME}"

[[ -z "$(command -v anka)" ]] && echo "must have anka CLI installed to use this script" && exit 1
echo "] Collecting Diagnostics from current machine (Please be patient)"

cleanup() {
  sudo rm -rf "${DIAG_PATH}"
}
cleanup

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
  for FULL_FILE_PATH in $(sudo -n -i bash -c "ls -t \"${DIR}\"/${FILTER}" 2>/dev/null | head -30); do
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
trap cleanup EXIT
CURRENT_USER="${USER}"
[[ $CURRENT_USER == root ]] && CURRENT_USER=
for CUSER in $CURRENT_USER root; do
  mkdir -p "${DIAG_PATH}/${CUSER}"
  [[ "${CUSER}" == root ]] && SUDO="sudo "
  pushd "${DIAG_PATH}/${CUSER}" &>/dev/null
    execute "${SUDO}anka version" &
    execute "${SUDO}anka list" &
    if [[ $(${SUDO}anka list | grep -c "|") -gt 0 ]]; then
      for TEMPLATE in $(${SUDO}anka list | grep "|" | grep -v uuid | awk '{print $2}'); do
        execute "${SUDO}anka show ${TEMPLATE}" &
        execute "${SUDO}anka show ${TEMPLATE} network" &
        execute "${SUDO}anka describe ${TEMPLATE}" &
      done
      for ITEM in $(${SUDO}launchctl list | grep ankahv | awk '{print $3}'); do
        execute "${SUDO}launchctl print system/${ITEM}" &
      done
    fi
    execute "${SUDO}anka config" &
    execute-multiple-times "${SUDO}df -h" &
    execute "${SUDO}ls -laht" &
    execute "${SUDO}sw_vers" &
    execute "${SUDO}ps -axm -o %mem,rss,comm" &
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
      execute "${SUDO}ankacluster --version" &
      execute "${SUDO}ankacluster status" &
      execute "${SUDO}launchctl list" &
      execute "${SUDO}ls -la /tmp/" &
      execute "${SUDO}ls -la /var/run/" &
      execute "${SUDO}kextstat" &
      execute "${SUDO}anka license show" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "system.log*" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "anka*.diag" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "anka*.crash" &
      copy-files-from-dir "/Library/Logs/DiagnosticReports" "Anka_*.hang" &
      copy-files-from-dir "/var/log/veertu" "anka_agent.*" &
      copy-files-from-dir "/var/log" "cloud-connect.log" &
      copy-files-from-dir "/var/log" "resize-disk.log" &
      execute-multiple-times "${SUDO}fs_usage -f diskio -t 2" 3 & # https://superuser.com/a/1542670
      wait $!
      execute-multiple-times "${SUDO}fs_usage -w -t 1" &
      copy-folders-from-dir "$($SUDO anka config vm_lib_dir)" &
      execute "${SUDO}log show --last 30m" &
      sleep 5
      execute "${SUDO}ps aux | grep VirtualMachine" &
      execute "${SUDO}ps aux | grep anka | grep -v generate-anka-node-diagnostics" &
    else
      copy-folders-from-dir "$($SUDO anka config vm_lib_dir)" &
    fi
    wait
  popd &>/dev/null
done
ZIP_NAME="anka-node-diagnostics-${UNIQUENESS}.zip"
pushd /tmp/ &>/dev/null
  sudo zip -9 -r $ZIP_NAME $DIAG_FOLDER_NAME 1>/dev/null
  sudo chown ${USER}:wheel $ZIP_NAME
popd &>/dev/null
sudo mv /tmp/$ZIP_NAME .
echo "]] Created $ZIP_NAME"
ls -l $ZIP_NAME
