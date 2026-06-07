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
  local path="$1"
  [[ -d "$path" ]] && return 0

  log "creating directory: $path"
  mkdir -p "$path"
  return 1
}

ensure_file_content() {
  local src="$1"
  local target="$2"
  cmp -s "$src" "$target" && return 0

  log "writing $target"
  mkdir -p "$(dirname "$target")"
  cp "$src" "$target"
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
  local chroot_path="${path#/mnt}"

  if [[ -n $recursive ]]; then
    arch-chroot /mnt find "$chroot_path" \
      \( -not -user "${user_group%:*}" -o -not -group "${user_group#*:}" \) \
      -print -quit | grep -q . || return 0
  else
    [[ $(arch-chroot /mnt stat -c "%U:%G" "$chroot_path" 2>/dev/null) == "$user_group" ]] && return 0
  fi

  log "setting /mnt$chroot_path ownership to $user_group${recursive:+ (recursive)}"
  arch-chroot /mnt chown ${recursive:+-R} "$user_group" "$chroot_path"
  return 1
}

ensure_symlink() {
  local target="$1"
  local link="$2"
  [[ $(readlink "$link" 2>/dev/null) == "$target" ]] && return 0

  log "linking $link -> $target"
  mkdir -p "$(dirname "$link")"
  ln -sf "$target" "$link"
  return 1
}

ensure_service_enabled() {
  local service="$1"
  arch-chroot /mnt systemctl is-enabled "$service" &>/dev/null && return 0

  log "enabling $service"
  arch-chroot /mnt systemctl enable "$service"
  return 1
}

source_lib() {
  local repo_root=$1
  for f in "$repo_root"/lib/*.sh; do source "$f"; done
}

script_dir() {
  # [1] = caller; [0] would be ourselves
  realpath "$(dirname "${BASH_SOURCE[1]}")"
}
