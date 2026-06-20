: "${time_zone:=}"

configure() {
  local changed=0

  if [[ $(readlink /etc/localtime) != "$time_zone" ]]; then
    log "setting the time zone"
    ln -sf "$time_zone" /etc/localtime
    changed=1
  fi

  hwclock --systohc || log "[WARNING] failed to set the hardware clock"

  if ! systemctl is-enabled systemd-timesyncd &>/dev/null; then
    log "enabling systemd-timesyncd"
    /mnt systemctl enable systemd-timesyncd
    changed=1
  fi

  return $changed
}
