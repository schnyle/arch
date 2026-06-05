: "${system_user:=}"

pulseaudio_pacman_packages=(
  pulseaudio
)
add_pacman_packages "${pulseaudio_pacman_packages[@]}"

pulseaudio_wants="/mnt/home/$system_user/.config/systemd/user/default.target.wants"
pulseaudio_symlink="$pulseaudio_wants/pulseaudio.service"
pulseaudio_target="/usr/lib/systemd/user/pulseaudio.service" # path as it will exist in the booted system (no /mnt prefix)

configure_pulseaudio() {
  require_var system_user

  local changed=0

  if [[ ! -d "$pulseaudio_wants" ]]; then
    log "creating pulseaudio systemd directory"
    mkdir -p "$pulseaudio_wants"
    changed=1
  fi

  if [[ $(readlink "$pulseaudio_symlink" 2>/dev/null) != "$pulseaudio_target" ]]; then
    log "enabling pulseaudio user service"
    ln -sf "$pulseaudio_target" "$pulseaudio_symlink"
    changed=1
  fi

  return $changed
}
