: "${hostname:=}"

configure_hostname() {
  require_var hostname

  [[ "$(cat /mnt/etc/hostname 2>/dev/null)" == "$hostname" ]] && return 0

  log "setting hostname to $hostname"
  echo "$hostname" >/mnt/etc/hostname
  return 1
}
