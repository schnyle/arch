: "${system_user:=}"
: "${email:=}"

ssh_key_pacman_packages=(
  openssh
)
add_pacman_packages "${ssh_key_pacman_packages[@]}"

ssh_key_private="/home/$system_user/.ssh/id_ed25519"
ssh_key_public="/home/$system_user/.ssh/id_ed25519.pub"

configure_ssh_key() {
  require_var system_user email

  local changed=0

  if ! [[ -f "/mnt$ssh_key_private" ]]; then
    log "creating ed25519 key for $system_user"
    arch-chroot /mnt sudo -u $system_user ssh-keygen -t ed25519 -C "$email" -f "$ssh_key_private" -N "" || return 1
    changed=1
  fi

  if [[ $(stat -c "%a" "/mnt/home/$system_user/.ssh") != "700" ]]; then
    log "setting permissions for /home/$system_user/.ssh/"
    chmod 700 "/mnt/home/$system_user/.ssh"
    changed=1
  fi

  if [[ $(stat -c "%a" "/mnt$ssh_key_private") != "600" ]]; then
    log "setting permissions for $ssh_key_private"
    chmod 600 "/mnt$ssh_key_private"
    changed=1
  fi

  if [[ $(stat -c "%a" "/mnt$ssh_key_public") != "644" ]]; then
    log "setting permissions for $ssh_key_public"
    chmod 644 "/mnt$ssh_key_public"
    changed=1
  fi

  return $changed
}
