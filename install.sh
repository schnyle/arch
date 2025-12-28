#!/bin/bash

# configuration
HOSTNAME="atlas"

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

ensure_package() {
  local pkg=$1
  if ! dpkg -s "$pkg" &>/dev/null; then
    log "installing $pkg"
    apt-get install -y "$pkg"
    changed
  fi
}

ensure_service() {
  local service=$1

  if ! systemctl is-enabled "$service" &>/dev/null; then
    log "enabling $service"
    systemctl enable "$service"
    changed
  fi

  if ! systemctl is-active "$service"; then
    log "starting $service"
    systemctl start "$service"
    changed
  fi
}

# start installation

apt-get update

if [[ "$(hostname)" != "$HOSTNAME" ]]; then
  log "setting hostname to '$HOSTNAME'"
  hostnamectl set-hostname "$HOSTNAME"
  changed
fi

# ssh
ensure_package "openssh-server"
ensure_package "avahi-daemon"
ensure_service "ssh"
ensure_service "avahi-daemon"

if [[ $CHANGES -gt 0 ]]; then
  log "restarting to verify $CHANGES changes"
  exec "$0"
fi

log "installation completed successfully"
