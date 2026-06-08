die() {
  log "ERROR: $*"
  exit 1
}

log() { echo "[LOG] $(date '+%H:%M:%S') $*" >&2; }

init_logging() {
  local log_file="$1"
  mkdir -p "$(dirname "$(realpath -m "$log_file")")"

  if [[ -z "${LOGGING_SETUP:-}" ]]; then
    exec 1> >(tee -a "$log_file")
    exec 2>&1
    export LOGGING_SETUP=1
  fi
}
