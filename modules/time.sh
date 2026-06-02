: "${time_zone:=}"

configure_time() {
  require_var time_zone

  local changed=0

  if [[ $(readlink /mnt/etc/localtime) != "$time_zone" ]]; then
    log "setting the time zone"
    ln -sf "$time_zone" /mnt/etc/localtime
    changed=1
  fi

  arch-chroot /mnt hwclock --systohc || log "[WARNING] failed to set the hardware clock"

  if ! arch-chroot /mnt systemctl is-enabled systemd-timesyncd &>/dev/null; then
    log "enabling systemd-timesyncd"
    arch-chroot /mnt systemctl enable systemd-timesyncd
    changed=1
  fi

  return $changed
}
