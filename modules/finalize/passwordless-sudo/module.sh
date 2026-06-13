: "${temp_sudoersd_file:=}"

configure() {
  [[ ! -f "/mnt$temp_sudoersd_file" ]] && return 0

  log "removing temporary passwordless sudo file"
  rm -f "/mnt$temp_sudoersd_file"
  return 1
}
