configure_disk() {
  if [[ -n $DISK_CONFIGURED ]]; then
    return 0
  fi

  log "configuring the disk"
  export DISK_CONFIGURED=1
  return 1
}
