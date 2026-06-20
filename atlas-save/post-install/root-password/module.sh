configure() {
  passwd -S root | grep -q " P " && return 0

  log "setting root password"
  sudo passwd
  return 1
}
