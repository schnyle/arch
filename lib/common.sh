# shellcheck disable=SC1090

log() { echo "[LOG] $(date '+%H:%M:%S') $*" >&2; }

init_logging() {
  local log_file="$1"
  local log_dir
  log_dir="$(dirname "$(realpath -m "$log_file")")"
  ensure_directory "$log_dir"

  if [[ -z "${LOGGING_SETUP:-}" ]]; then
    exec 1> >(tee -a "$log_file")
    exec 2>&1
    export LOGGING_SETUP=1
  fi
}

ensure_directory() {
  local dir="$1"
  if ! [[ -d "$dir" ]]; then
    log "creating directory: $1"
    mkdir -p "$dir"
  fi
}

source_lib() {
  local repo_root=$1
  for f in "$repo_root"/lib/*.sh; do source "$f"; done
}

source_modules() {
  local repo_root=$1
  shift
  for m in "$@"; do source "$repo_root/modules/$m.sh"; done
}

run_modules() {
  for m in "$@"; do "configure_${m//-/_}"; done
}

converge_modules() {
  while true; do
    local changes=0
    for m in "$@"; do
      "configure_${m//-/_}" || changes=$((changes + 1))
    done
    [[ $changes -eq 0 ]] && break
    log "restarting convergence loop"
  done
}

select_install_device() {
  local install_device
  while true; do
    echo "available devices:" >&2
    lsblk -d -n -o NAME,SIZE,TYPE >&2
    echo >&2
    read -r -p "enter device name: " install_device
    install_device="/dev/$install_device"

    [[ -b "$install_device" ]] && break

    echo "device '$install_device' not found, try again" >&2
  done
  echo "$install_device"
}

confirm_wipe_device() {
  local device=$1
  local input
  if lsblk -n "$device" | grep -q part; then
    echo "WARNING: device $device is already partitioned" >&2
    lsblk "$device" >&2
    read -r -p "Continue? (yes/no): " input
    if [[ "$input" != "yes" ]]; then
      log "install aborted by user"
      exit 1
    fi
  fi
}
