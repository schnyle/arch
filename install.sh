#!/bin/bash

LOG_FILE="/var/log/install.log"
DEBUG_LOG_FILE="/var/log/install-debug.log"

if [[ $EUID -ne 0 ]]; then
  echo "installation script must be run as sudo"
  exit 1
fi

# logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a $LOG_FILE; }

# redirect output to verbose log file
if [[ -z "$LOGGING_SETUP" ]]; then
  log "starting Atlas installation"
  exec 1> >(tee -a $DEBUG_LOG_FILE)
  exec 2>&1
  export LOGGING_SETUP=1
fi

restartnow() { log "restarting install script" && exec "$(realpath "$0")"; }

CHANGES=0
changed() { ((CHANGES++)); }

# do installation

if [[ $CHANGES -gt 0 ]]; then
  log "restarting to verify $CHANGES changes"
  exec "$0"
fi

log "installation completed successfully"
