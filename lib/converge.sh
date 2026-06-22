# shellcheck disable=SC1090

: "${repo_root:=}"

run_configure() {
  local module_file="$1"
  (
    source "$module_file"
    declare -f configure >/dev/null || exit 0
    configure
  )
}

converge_modules() {
  local max_attempts=5
  local -A attempts

  while true; do
    local changes=0
    for module in "$@"; do
      local module_file="$repo_root/modules/$module/module.sh"
      [[ ! -f "$module_file" ]] && continue

      if ! run_configure "$module_file"; then
        changes=$((changes + 1))
        attempts[$module]=$((${attempts[$module]:-0} + 1))
        [[ ${attempts[$module]} -ge $max_attempts ]] && die "$module module failed after ${attempts[$module]} attempts"
      fi
    done
    [[ $changes -eq 0 ]] && break
    log "restarting convergence loop"
  done
}
