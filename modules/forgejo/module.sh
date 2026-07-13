: "${forgejo_ssh_port:=}"
: "${forgejo_http_port:=}"

pacman_packages=(
  forgejo
  sqlite
)

configure() {
  local changed=0

  local forgejo_dir=/storage/forgejo
  local forgejo_ini=/etc/forgejo/app.ini
  local forgejo_id=909

  if [[ $(id -u forgejo 2>/dev/null) != "$forgejo_id" ]]; then
    log "pinning forgejo UID to $forgejo_id"
    usermod -u "$forgejo_id" forgejo
    changed=1
  fi

  if [[ $(getent group forgejo | cut -d: -f3) != "$forgejo_id" ]]; then
    log "pinning forgejo GID to $forgejo_id"
    groupmod -g "$forgejo_id" forgejo
    changed=1
  fi

  ensure_file_ownership -R root:forgejo /etc/forgejo || changed=1
  ensure_file_ownership -R root:forgejo /var/log/forgejo || changed=1

  ensure_service_enabled forgejo || changed=1

  ensure_directory "$forgejo_dir" || changed=1
  ensure_file_ownership -R forgejo:forgejo "$forgejo_dir" || changed=1
  ensure_file_permissions 750 "$forgejo_dir" || changed=1

  local desired_path="PATH=/storage/forgejo/data/forgejo.db"
  if ! grep -Eq "^PATH[[:space:]]*=[[:space:]]*/storage/forgejo/data/forgejo\.db[[:space:]]*\$" "$forgejo_ini"; then
    log "setting database PATH in $forgejo_ini"
    sed -i "/^\[database\]/,/^\[/{s|^;\?PATH[[:space:]]*=.*|$desired_path|}" "$forgejo_ini"
    changed=1
  fi

  local desired_app_data_path="APP_DATA_PATH=/storage/forgejo/data"
  if ! grep -Eq "^APP_DATA_PATH[[:space:]]*=[[:space:]]*/storage/forgejo/data[[:space:]]*\$" "$forgejo_ini"; then
    log "setting APP_DATA_PATH in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?APP_DATA_PATH[[:space:]]*=.*|$desired_app_data_path|}" "$forgejo_ini"
    changed=1
  fi

  local desired_domain="DOMAIN=atlas.local"
  if ! grep -Eq "^DOMAIN[[:space:]]*=[[:space:]]*atlas\.local[[:space:]]*\$" "$forgejo_ini"; then
    log "setting DOMAIN in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?DOMAIN[[:space:]]*=.*|$desired_domain|}" "$forgejo_ini"
    changed=1
  fi

  local desired_install_lock="INSTALL_LOCK=true"
  if ! grep -Eq "^INSTALL_LOCK[[:space:]]*=[[:space:]]*true[[:space:]]*\$" "$forgejo_ini"; then
    log "setting INSTALL_LOCK in $forgejo_ini"
    sed -i "s|^;\?INSTALL_LOCK[[:space:]]*=.*|$desired_install_lock|" "$forgejo_ini"
    changed=1
  fi

  local desired_http_port="HTTP_PORT=$forgejo_http_port"
  if ! grep -Eq "^HTTP_PORT[[:space:]]*=[[:space:]]*$forgejo_http_port[[:space:]]*\$" "$forgejo_ini"; then
    log "setting HTTP_PORT in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?HTTP_PORT[[:space:]]*=.*|$desired_http_port|}" "$forgejo_ini"
    changed=1
  fi

  local desired_ssh_domain="SSH_DOMAIN=atlas.local"
  if ! grep -Eq "^SSH_DOMAIN[[:space:]]*=[[:space:]]*atlas\.local[[:space:]]*\$" "$forgejo_ini"; then
    log "setting SSH_DOMAIN in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?SSH_DOMAIN[[:space:]]*=.*|$desired_ssh_domain|}" "$forgejo_ini"
    changed=1
  fi

  local desired_start_ssh="START_SSH_SERVER=true"
  if ! grep -Eq "^START_SSH_SERVER[[:space:]]*=[[:space:]]*true[[:space:]]*\$" "$forgejo_ini"; then
    log "enabling forgejo's built-in ssh server"
    sed -i "/^\[server\]/,/^\[/{s|^;\?START_SSH_SERVER[[:space:]]*=.*|$desired_start_ssh|}" "$forgejo_ini"
    changed=1
  fi

  local desired_ssh_port="SSH_PORT=$forgejo_ssh_port"
  if ! grep -Eq "^SSH_PORT[[:space:]]*=[[:space:]]*$forgejo_ssh_port[[:space:]]*\$" "$forgejo_ini"; then
    log "setting SSH_PORT in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?SSH_PORT[[:space:]]*=.*|$desired_ssh_port|}" "$forgejo_ini"
    changed=1
  fi

  local desired_ssh_listen_port="SSH_LISTEN_PORT=$forgejo_ssh_port"
  if ! grep -Eq "^SSH_LISTEN_PORT[[:space:]]*=[[:space:]]*$forgejo_ssh_port[[:space:]]*\$" "$forgejo_ini"; then
    log "setting SSH_LISTEN_PORT in $forgejo_ini"
    sed -i "/^\[server\]/,/^\[/{s|^;\?SSH_LISTEN_PORT[[:space:]]*=.*|$desired_ssh_listen_port|}" "$forgejo_ini"
    changed=1
  fi

  local forgejo_override=/etc/systemd/system/forgejo.service.d/override.conf
  local desired_override=$'[Service]\nReadWritePaths=/storage/forgejo'

  if [[ "$(cat "$forgejo_override" 2>/dev/null)" != "$desired_override" ]]; then
    log "writing forgejo systemd override"
    mkdir -p "$(dirname "$forgejo_override")"
    echo "[Service]" >"$forgejo_override"
    echo "ReadWritePaths=/storage/forgejo" >>"$forgejo_override"
    systemctl daemon-reload
    changed=1
  fi

  sudo -u forgejo forgejo migrate -c "$forgejo_ini"

  local admin_username=schnyle
  local admin_email=kylesch115@gmail.com

  if ! sudo -u forgejo forgejo admin user list -c "$forgejo_ini" | grep -qw "$admin_username"; then
    log "creating forgejo admin user $admin_username"
    local admin_password
    read -rs -p "forgejo admin password for $admin_username: " admin_password
    echo
    sudo -u forgejo forgejo admin user create \
      --username "$admin_username" \
      --password "$admin_password" \
      --email "$admin_email" \
      --admin \
      -c "$forgejo_ini"
    changed=1
  fi

  return $changed
}
