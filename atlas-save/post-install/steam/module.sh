pacman_packages=(
  steam
)

configure() {
  local changed=0

  grep -q "^\[multilib\]" /etc/pacman.conf && return 0

  if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    log "enabling 32-bit libraries"
    sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /etc/pacman.conf
    changed=1
  fi

  if [[ ! -f /var/lib/pacman/sync/multilib.db ]]; then
    log "syncing pacman database"
    pacman -Sy
    changed=1
  fi

  return $changed
}
