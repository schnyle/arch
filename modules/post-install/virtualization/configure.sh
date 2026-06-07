# virtualization stack is installed; libvirtd is enabled and user is a member of the libvirtd group.

: "${system_user:=}"

configure() {
  local changed=0

  ensure_service_enabled libvirtd.socket || changed=1

  if ! arch-chroot /mnt groups "$system_user" | grep -q libvirt; then
    log "adding user to libvirt group"
    arch-chroot /mnt usermod -aG libvirt "$system_user"
    changed=1
  fi

  return $changed
}
