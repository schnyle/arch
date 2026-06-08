# An ed25519 SSH key is setup with proper file permissions.

: "${system_user:=}"
: "${email:=}"

configure() {
  local changed=0
  local ssh_dir="/home/$system_user/.ssh"
  local ssh_key_private="$ssh_dir/id_ed25519"
  local ssh_key_public="$ssh_dir/id_ed25519.pub"

  if ! [[ -f "$ssh_key_private" ]]; then
    log "creating ed25519 key for $system_user"
    sudo -u "$system_user" ssh-keygen -t ed25519 -C "$email" -f "$ssh_key_private" -N "" || return 1
    changed=1
  fi

  ensure_file_permissions 700 "$ssh_dir" || changed=1
  ensure_file_permissions 600 "$ssh_key_private" || changed=1
  ensure_file_permissions 644 "$ssh_key_public" || changed=1

  return $changed
}
