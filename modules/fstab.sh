configure_fstab() {
  grep -q "^UUID=" /mnt/etc/fstab && return 0

  log "generating fstab file"
  genfstab -U /mnt >>/mnt/etc/fstab
  return 1
}
