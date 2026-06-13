mirrors_conf="/mnt/etc/xdg/reflector/reflector.conf"

configure() {
  local changed=0

  if ! arch-chroot /mnt pacman -Q reflector &>/dev/null; then
    log "installing reflector"
    arch-chroot /mnt pacman -S --noconfirm reflector
    changed=1
  fi

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

  if ! arch-chroot /mnt systemctl is-enabled reflector.timer &>/dev/null; then
    log "enabling reflector.timer daemon"
    arch-chroot /mnt systemctl enable reflector.timer
    changed=1
  fi

  return $changed
}
