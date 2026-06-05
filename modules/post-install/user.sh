: "${system_user:=}"
: "${temp_sudoersd_file:=}"

configure_user() {
  require_var system_user temp_sudoersd_file

  local changed=0

  if ! arch-chroot /mnt id "$system_user" &>/dev/null; then
    log "creating user $system_user"
    arch-chroot /mnt useradd -m -G wheel "$system_user"
    changed=1
  fi

  if ! arch-chroot /mnt passwd -S "$system_user" | grep -q " P "; then
    log "setting password for $system_user"
    arch-chroot /mnt bash -c "passwd '$system_user'"
    changed=1
  fi

  if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /mnt/etc/sudoers; then
    log "allowing sudo for wheel group users"
    sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /mnt/etc/sudoers
    changed=1
  fi

  # Create a temporary file which allows the user to run sudo commands without password prompt.
  # Removed at the end of the installation.
  if ! grep -q "$system_user ALL=(ALL) NOPASSWD: ALL" "/mnt$temp_sudoersd_file" &>/dev/null || [[ $(stat -c "%a" "/mnt$temp_sudoersd_file") != "440" ]]; then
    log "configuring temporary passwordless sudo for $system_user"
    bash -c "echo '$system_user ALL=(ALL) NOPASSWD: ALL' >/mnt$temp_sudoersd_file"
    chmod 440 "/mnt$temp_sudoersd_file"
    changed=1
  fi

  return $changed
}
