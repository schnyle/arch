configure_root_password() {
  arch-chroot /mnt passwd -S root | grep -q " P " && return 0

  log "setting root password"
  arch-chroot /mnt bash -c "passwd"
  return 1
}
