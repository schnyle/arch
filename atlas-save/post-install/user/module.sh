# System user exists with password, wheel group membership, and a temporary
# passwordless-sudo entry (removed at the end of post-install.sh).

: "${system_user:=}"
: "${temp_sudoersd_file:=}"

configure() {
  local changed=0

  if ! id "$system_user" &>/dev/null; then
    log "creating user $system_user"
    useradd -m -G wheel "$system_user"
    changed=1
  fi

  if ! passwd -S "$system_user" | grep -q " P "; then
    log "setting password for $system_user"
    passwd "$system_user"
    changed=1
  fi

  if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    log "allowing sudo for wheel group users"
    sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
    changed=1
  fi

  if ! grep -q "$system_user ALL=(ALL) NOPASSWD: ALL" "$temp_sudoersd_file" &>/dev/null; then
    log "configuring temporary passwordless sudo for $system_user"
    echo "$system_user ALL=(ALL) NOPASSWD: ALL" >"$temp_sudoersd_file"
    changed=1
  fi

  ensure_file_permissions 440 "$temp_sudoersd_file" || changed=1

  return $changed
}
