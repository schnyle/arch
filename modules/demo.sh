add_pacman_packages \
  git \
  nvim \
  nano

configure_demo() {
  if [[ -n $DEMO ]]; then
    return 0
  fi

  log "configuring the configuration"
  export DEMO=1
  return 1
}
