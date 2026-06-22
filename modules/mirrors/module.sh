pacman_packages=(
  reflector
)

configure() {
  local changed=0
  local mirrors_conf="/etc/xdg/reflector/reflector.conf"

  if ! grep -q -- "--latest 10" "$mirrors_conf"; then
    log "setting reflector --latest 10"
    sed -i "s/--latest .*/--latest 10/g" "$mirrors_conf"
    changed=1
  fi

  if ! grep -q -- "--sort rate" "$mirrors_conf"; then
    log "setting reflector --sort rate"
    sed -i "s/--sort .*/--sort rate/g" "$mirrors_conf"
    changed=1
  fi

  if ! systemctl is-enabled reflector.timer &>/dev/null; then
    log "enabling reflector.timer daemon"
    systemctl enable reflector.timer
    changed=1
  fi

  return $changed
}
