arandr_pacman_packages=(
  arandr
)
add_pacman_packages "${arandr_pacman_packages[@]}"

configure_arandr() {
  [[ $(readlink /mnt/usr/local/bin/displays 2>/dev/null) == /usr/bin/arandr ]] && return 0

  log "creating symlink for arandr"
  arch-chroot /mnt ln -sf /usr/bin/arandr /usr/local/bin/displays
  return 1
}
