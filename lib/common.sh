log() { echo "[LOG] $(date '+%H:%M:%S') $*"; }

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
