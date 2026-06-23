: "${ssh_port:=}"

pacman_packages=(ufw)

configure() {
  local changed=0

  if ! ufw status verbose | grep -q "deny (incoming)"; then
    log "ufw: setting default deny incoming"
    ufw default deny incoming
    changed=1
  fi

  if ! ufw status verbose | grep -q "allow (outgoing)"; then
    log "ufw: setting default allow outgoing"
    ufw default allow outgoing
    changed=1
  fi

  if ! ufw status verbose | grep -q "$ssh_port/tcp.*ALLOW"; then
    log "ufw: allowing TCP on port $ssh_port"
    ufw allow "$ssh_port/tcp"
    changed=1
  fi

  ensure_service_enabled ufw || changed=1

  if ! ufw status | grep -q "Status: active"; then
    log "ufw: activating firewall"
    ufw --force enable
    changed=1
  fi

  return $changed
}
