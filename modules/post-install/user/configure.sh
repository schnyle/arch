# System user exists with password, wheel group membership, and a temporary
# passwordless-sudo entry (should be removed in finalize).

: "${system_user:=}"
: "${temp_sudoersd_file:=}"

configure() {
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

  if ! grep -q "$system_user ALL=(ALL) NOPASSWD: ALL" "/mnt$temp_sudoersd_file" &>/dev/null; then
    log "configuring temporary passwordless sudo for $system_user"
    echo "$system_user ALL=(ALL) NOPASSWD: ALL" >"/mnt$temp_sudoersd_file"
    changed=1
  fi

  ensure_file_permissions 440 "/mnt$temp_sudoersd_file" || changed=1

  return $changed
}
