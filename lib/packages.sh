: "${repo_root:=}"

get_pacman_packages() {
  local -n _out="$1"
  shift

  mapfile -t _out < <(
    for module in "$@"; do
      local module_file="$repo_root/modules/post-install/$module/module.sh"
      [[ -f "$module_file" ]] || continue
      (
        source "$module_file"
        [[ ${#pacman_packages[@]} -gt 0 ]] && printf '%s\n' "${pacman_packages[@]}"
      )
    done | sort -u
  )
}

install_pacman_packages() {
  local max_attempts=5
  local attempt=0
  local missing

  [[ $# -eq 0 ]] && return 0

  while [[ $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))
    log "installing $# pacman packages (attempt $attempt/$max_attempts)"
    pacman -Sy
    pacman -S --noconfirm --needed "$@"

    mapfile -t missing < <(pacman -Q "$@" 2>&1 |
      awk -F"'" '/was not found/ {print $2}')
    [[ ${#missing[@]} -eq 0 ]] && return 0
    log "${#missing[@]} packages still missing: ${missing[*]}"
  done

  die "${#missing[@]} packages missing after $max_attempts attempts: ${missing[*]}"
}

handle_unknown_pacman_packages() {
  local -n _packages="$1"
  [[ ${#_packages[@]} -eq 0 ]] && return 0

  pacman -Sy >/dev/null

  local unknown
  mapfile -t unknown < <(pacman -Si "${_packages[@]}" 2>&1 >/dev/null | awk -F"'" '/was not found/ {print $2}')
  [[ ${#unknown[@]} -eq 0 ]] && return 0

  log "WARNING: unknown pacman packages: ${unknown[*]}"
  read -rp "skip these and continue? (yes/no) " ans
  [[ $ans == "yes" ]] || die "aborting"

  declare -A skip
  for p in "${unknown[@]}"; do skip[$p]=1; done

  local filtered=()
  for p in "${_packages[@]}"; do
    [[ -z ${skip[$p]:-} ]] && filtered+=("$p")
  done
  _packages=("${filtered[@]}")
}
