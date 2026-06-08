ensure_directory() {
  local user=
  if [[ $1 == "-u" ]]; then
    user=$2
    shift 2
  fi

  local path="$1"

  [[ -d "$path" ]] && return 0

  log "creating directory: $path${user:+ as $user}"
  if [[ -n "$user" ]]; then
    sudo -u "$user" mkdir -p "$path"
  else
    mkdir -p "$path"
  fi

  return 1
}

ensure_file_content() {
  local user=
  if [[ $1 == "-u" ]]; then
    user=$2
    shift 2
  fi

  local src="$1"
  local target="$2"

  cmp -s "$src" "$target" && return 0

  log "writing $target${user:+ as $user}"
  if [[ -n "$user" ]]; then
    sudo -u "$user" mkdir -p "$(dirname "$target")"
    sudo -u "$user" cp "$src" "$target"
  else
    mkdir -p "$(dirname "$target")"
    cp "$src" "$target"
  fi

  return 1
}

ensure_file_permissions() {
  local mode="$1"
  local path="$2"
  [[ $(stat -c "%a" "$path") == "$mode" ]] && return 0

  log "setting $path permissions to $mode"
  chmod "$mode" "$path"
  return 1
}

ensure_file_ownership() {
  local recursive=
  if [[ $1 == -R ]]; then
    recursive=1
    shift
  fi

  local user_group="$1"
  local path="$2"

  if [[ -n $recursive ]]; then
    find "$path" \
      \( -not -user "${user_group%:*}" -o -not -group "${user_group#*:}" \) \
      -print -quit | grep -q . || return 0
  else
    [[ $(stat -c "%U:%G" "$path" 2>/dev/null) == "$user_group" ]] && return 0
  fi

  log "setting $path ownership to $user_group${recursive:+ (recursive)}"
  chown ${recursive:+-R} "$user_group" "$path"
  return 1
}

ensure_symlink() {
  local user=
  if [[ $1 == "-u" ]]; then
    user=$2
    shift 2
  fi

  local target="$1"
  local link="$2"

  [[ $(readlink "$link" 2>/dev/null) == "$target" ]] && return 0

  log "linking $link -> $target${user:+ as $user}"
  if [[ -n $user ]]; then
    sudo -u "$user" mkdir -p "$(dirname "$link")"
    sudo -u "$user" ln -sf "$target" "$link"
  else
    mkdir -p "$(dirname "$link")"
    ln -sf "$target" "$link"
  fi

  return 1
}

ensure_service_enabled() {
  local service="$1"
  systemctl is-enabled "$service" &>/dev/null && return 0

  log "enabling $service"
  systemctl enable "$service"
  return 1
}

script_dir() {
  # [1] = caller; [0] would be ourselves
  realpath "$(dirname "${BASH_SOURCE[1]}")"
}
