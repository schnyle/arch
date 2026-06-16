: "${log_file:=}"

configure() {
  [[ -f "/mnt$log_file" ]] && return 0

  log "copying log files to target system"
  cp "$log_file" "/mnt$log_file"
  return 1
}
