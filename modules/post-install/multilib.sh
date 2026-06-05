configure_multilib() {
  grep -q "^\[multilib\]" /mnt/etc/pacman.conf && return 0

  log "enabling 32-bit libraries"
  sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /mnt/etc/pacman.conf
  arch-chroot /mnt pacman -Sy
  return 1
}
