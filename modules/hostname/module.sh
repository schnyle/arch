: "${hostname:=}"

configure() {
  [[ "$(cat /etc/hostname 2>/dev/null)" == "$hostname" ]] && return 0

  log "setting hostname to $hostname"
  echo "$hostname" >/etc/hostname
  return 1
}
