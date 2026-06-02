configure_user() {
  if [[ -n $SETUP_USER ]]; then
    return 0
  fi

  log "creating the user"
  export SETUP_USER=1
  return 1
}
