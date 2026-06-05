# shellcheck disable=SC1090

source_modules() {
  local repo_root=$1
  shift

  for m in "$@"; do
    local matches
    matches=$(find "$repo_root/modules" -type f -name "$m.sh")
    [[ -z $matches ]] && die "$m module not found"

    if [[ $(wc -l <<<"$matches") -gt 1 ]]; then
      log "$m module is ambiguous:"
      echo "  ${matches//$'\n'/$'\n  '}"
      die "module names must be unique across modules/"
    fi

    source "$matches"
  done
}

converge_ordered() {
  local max_attempts=5

  for m in "$@"; do
    local attempts=0
    until "configure_${m//-/_}"; do
      attempts=$((attempts + 1))
      [[ $attempts -ge $max_attempts ]] && die "$m module failed after $attempts attempts"

      # skip the expected re-verify pass; only log subsequent retries
      if [[ $attempts -gt 1 ]]; then
        log "$m module did not converge, retrying ($attempts/$max_attempts)"
        sleep 2
      fi
    done
  done
}

# TODO: should we bound the attempts for each module?
converge_unordered() {
  local max_attempts=5
  local -A attempts

  while true; do
    local changes=0
    for m in "$@"; do
      if ! "configure_${m//-/_}"; then
        changes=$((changes + 1))
        attempts[$m]=$((${attempts[$m]:-0} + 1))
        [[ ${attempts[$m]} -ge $max_attempts ]] && die "$m module failed after ${attempts[$m]} attempts"
      fi
    done
    [[ $changes -eq 0 ]] && break
    log "restarting convergence loop"
  done
}
