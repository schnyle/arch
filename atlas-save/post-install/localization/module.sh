configure() {
  local changed=0

  if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
    log "enabling en_US.UTF-8 locale"
    sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen
    changed=1
  fi

  if ! locale -a | grep -q "en_US.utf8"; then
    log "generating locales"
    locale-gen
    changed=1
  fi

  if [[ "$(cat etc/locale.conf 2>/dev/null)" != "LANG=en_US.UTF-8" ]]; then
    log "creating locale.conf and setting LANG"
    echo "LANG=en_US.UTF-8" >/etc/locale.conf
    changed=1
  fi

  return $changed
}
