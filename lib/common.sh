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

die() {
  log "ERROR: $*"
  exit 1
}

require_var() {
  for name in "$@"; do
    [[ -z "${!name:-}" ]] && die "$name is required but not set"
  done
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

