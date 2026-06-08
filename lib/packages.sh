get_pacman_packages() {
  local -n _out="$1"
  shift

  mapfile -t _out < <(
    for module in "$@"; do
      local pacman_file="$repo_root/modules/post-install/$module/pacman"
      [[ -f "$pacman_file" ]] || continue
      awk '!/^\s*(#|$)/ {print $1}' "$pacman_file"
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
