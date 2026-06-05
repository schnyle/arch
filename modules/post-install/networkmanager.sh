networkmanager_pacman_packages=(
  networkmanager # network connection manager and user application
)
add_pacman_packages "${networkmanager_pacman_packages[@]}"

configure_networkmanager() {
  arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null && return 0

  log "enabling NetworkManager"
  arch-chroot /mnt systemctl enable NetworkManager
  return 1
}
