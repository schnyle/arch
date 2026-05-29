configure_cleanup() {
  if [[ -n $CLEANED ]]; then
    return 0
  fi

  log "performing cleanup"
  export CLEANED=1
  return 1
}
