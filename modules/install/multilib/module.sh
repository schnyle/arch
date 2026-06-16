# multilib is enabled for 32-bit libraries.

configure() {
  local changed=0

  grep -q "^\[multilib\]" /mnt/etc/pacman.conf && return 0

  if ! grep -q "^\[multilib\]" /mnt/etc/pacman.conf; then
    log "enabling 32-bit libraries"
    sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /mnt/etc/pacman.conf
    changed=1
  fi

  if [[ ! -f /mnt/var/lib/pacman/sync/multilib.db ]]; then
    log "syncing pacman database"
    arch-chroot /mnt pacman -Sy
    changed=1
  fi

  return $changed
}
