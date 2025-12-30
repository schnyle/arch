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

# set hostname
if [[ "$(hostname)" != "$HOSTNAME" ]]; then
  log "setting hostname to '$HOSTNAME'"
  hostnamectl set-hostname "$HOSTNAME"
  changed
fi

# ssh & DNS discovery
ensure_package "openssh-server"
ensure_package "avahi-daemon"
ensure_service "ssh"
ensure_service "avahi-daemon"

# disable sleep states
sleep_targets=(
  "sleep.target"
  "suspend.target"
  "hibernate.target"
  "hybrid-sleep.target"
)
for target in "${sleep_targets[@]}"; do
  if [ "$(systemctl is-enabled "$target" 2>/dev/null)" != "masked" ]; then
    log "masking $target"
    systemctl mask "$target"
    changed
  fi
done

# firewall setup
if ! command -v ufw &>/dev/null; then
  log "installing ufw"
  apt-get install -y ufw
  restartnow
fi

if ! ufw status verbose | grep -q "deny (incoming)"; then
  log "ufw: setting default deny incoming"
  ufw default deny incoming
  changed
fi

if ! ufw status verbose | grep -q "allow (outgoing)"; then
  log "ufw: setting default allow outgoing"
  ufw default allow outgoing
  changed
fi

if ! ufw status | grep -q "22/tcp.*ALLOW"; then
  log "ufw: allowing TCP on port 22"
  ufw allow 22/tcp
  changed
fi

if ! ufw status | grep -q "Status: active"; then
  log "ufw: enabling firewall"
  ufw --force enable
  restartnow
fi

if [[ $CHANGES -gt 0 ]]; then
  log "restarting to verify $CHANGES changes"
  exec "$(realpath "$0")"
fi

log "installation completed successfully"
