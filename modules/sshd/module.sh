: "${ssh_port:=}"

pacman_packages=(openssh)

configure() {
  local changed=0
  local config=/etc/ssh/sshd_config

  if ! grep -q "^PermitRootLogin no" "$config"; then
    log "disabling root login in sshd_config"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$config"
    changed=1
  fi

  if ! grep -q "^Port $ssh_port\$" "$config"; then
    log "setting sshd port to $ssh_port"
    sed -i "s/^#\?Port .*/Port $ssh_port/" "$config"
    changed=1
  fi

  ensure_service_enabled sshd || changed=1

  return $changed
}
