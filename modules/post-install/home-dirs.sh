: "${system_user:=}"

home_dirs=(
  docs
  media
  misc
  repos
)

user_dirs_content=$(
  cat <<"EOF"
XDG_DOWNLOAD_DIR="/tmp"
XDG_DESKTOP_DIR="$HOME/misc"
XDG_DOCUMENTS_DIR="$HOME/docs"
XDG_MUSIC_DIR="$HOME/media"
XDG_PICTURES_DIR="$HOME/media"
XDG_VIDEOS_DIR="$HOME/media"
XDG_TEMPLATES_DIR="$HOME/misc"
XDG_PUBLICSHARE_DIR="$HOME/misc"
EOF
)

configure_home_dirs() {
  require_var system_user

  local changed=0

  if ! [[ -d "/mnt/home/$system_user/.config" ]]; then
    log "creating user config directory"
    mkdir "/mnt/home/$system_user/.config"
    arch-chroot /mnt chown "$system_user:$system_user" "/home/$system_user/.config"
    changed=1
  fi

  if [[ "$(cat "/mnt/home/$system_user/.config/user-dirs.dirs" 2>/dev/null)" != "$user_dirs_content" ]]; then
    log "creating XDG directory mapping file"
    echo "$user_dirs_content" >"/mnt/home/$system_user/.config/user-dirs.dirs"
    arch-chroot /mnt chown "$system_user:$system_user" "/home/$system_user/.config/user-dirs.dirs"
    changed=1
  fi

  if [[ "$(cat "/mnt/home/$system_user/.config/user-dirs.conf" 2>/dev/null)" != "enabled=False" ]]; then
    log "disabling XDG directory mapping regeneration"
    echo "enabled=False" >"/mnt/home/$system_user/.config/user-dirs.conf"
    arch-chroot /mnt chown "$system_user:$system_user" "/home/$system_user/.config/user-dirs.conf"
    changed=1
  fi

  for dir in "${home_dirs[@]}"; do
    if ! [[ -d "/mnt/home/$system_user/$dir" ]]; then
      log "creating $dir user home directory"
      mkdir "/mnt/home/$system_user/$dir"
      arch-chroot /mnt chown "$system_user:$system_user" "/home/$system_user/$dir"
      changed=1
    fi
  done

  return $changed
}
