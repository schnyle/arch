# shellcheck disable=SC1090

: "${repo_root:=}"

validate_required_vars() {
  local phase="$1"
  shift

  local declared=()
  for m in "$@"; do
    local module_file="$repo_root/modules/$phase/$m/module.sh"
    [[ -f "$module_file" ]] || continue
    while IFS= read -r var; do
      declared+=("$var")
    done < <(grep -oP '^\s*:\s*"\$\{\K[a-zA-Z_][a-zA-Z_0-9]*' "$module_file")
  done

  local missing=()
  for var in $(printf '%s\n' "${declared[@]}" | sort -u); do
    [[ -z "${!var:-}" ]] && missing+=("$var")
  done

  [[ ${#missing[@]} -gt 0 ]] && die "host missing required vars: ${missing[*]}"
}

run_configure() {
  local module_file="$1"
  (
    source "$module_file"
    declare -f configure >/dev/null || exit 0
    configure
  )
}

converge_modules_ordered() {
  local phase="$1"
  shift

  local max_attempts=5

  for m in "$@"; do
    local module_file="$repo_root/modules/$phase/$m/module.sh"
    [[ ! -f "$module_file" ]] && continue

    local attempts=0
    until run_configure "$module_file"; do
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

converge_modules_unordered() {
  local phase="$1"
  shift

  local max_attempts=5
  local -A attempts

  while true; do
    local changes=0
    for m in "$@"; do
      local module_file="$repo_root/modules/$phase/$m/module.sh"
      [[ ! -f "$module_file" ]] && continue

      if ! run_configure "$module_file"; then
        changes=$((changes + 1))
        attempts[$m]=$((${attempts[$m]:-0} + 1))
        [[ ${attempts[$m]} -ge $max_attempts ]] && die "$m module failed after ${attempts[$m]} attempts"
      fi
    done
    [[ $changes -eq 0 ]] && break
    log "restarting convergence loop"
  done
}
