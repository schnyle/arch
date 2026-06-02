configure_localization() {
  local changed=0

  if ! grep -q "^en_US.UTF-8 UTF-8" /mnt/etc/locale.gen; then
    log "enabling en_US.UTF-8 locale"
    sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /mnt/etc/locale.gen
    changed=1
  fi

  if ! arch-chroot /mnt locale -a | grep -q "en_US.utf8"; then
    log "generating locales"
    arch-chroot /mnt locale-gen
    changed=1
  fi

  if [[ "$(cat /mnt/etc/locale.conf 2>/dev/null)" != "LANG=en_US.UTF-8" ]]; then
    log "creating locale.conf and setting LANG"
    echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
    changed=1
  fi

  return $changed
}
