pavucontrol_pacman_packages=(
  pavucontrol
)
add_pacman_packages "${pavucontrol_pacman_packages[@]}"

configure_pavucontrol() {
  [[ $(readlink /mnt/usr/local/bin/audio 2>/dev/null) == /usr/bin/pavucontrol ]] && return 0

  log "creating symlink for pavucontrol"
  arch-chroot /mnt ln -sf /usr/bin/pavucontrol /usr/local/bin/audio
  return 1
}
