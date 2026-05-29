# shellcheck disable=SC1090

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
