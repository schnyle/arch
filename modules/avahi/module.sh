pacman_packages=(
  avahi
  nss-mdns
)

configure() {
  local changed=0

  ensure_service_enabled avahi-daemon || changed=1

  if ! grep -qE '^hosts:.*mdns_minimal' /etc/nsswitch.conf; then
    log "adding mdns_minimal to nsswitch.conf hosts"
    sed -i -E '/^hosts:/ s/(resolve|dns)/mdns_minimal [NOTFOUND=return] &/' /etc/nsswitch.conf
    changed=1
  fi

  return $changed
}
