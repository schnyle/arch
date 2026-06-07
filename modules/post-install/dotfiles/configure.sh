# Dotfiles are cloned and stowed.

: "${system_user:=}"

configure() {
  local changed=0

  local dotfiles_dir="/home/$system_user/.dotfiles"

  if [[ ! -d "/mnt$dotfiles_dir/.git" ]]; then
    log "cloning dotfiles repository"
    arch-chroot /mnt sudo -u "$system_user" git clone https://github.com/schnyle/dotfiles.git "$dotfiles_dir"
    changed=1
  fi

  if [[ ! -f "/mnt$dotfiles_dir/.dotfiles-installed" ]]; then
    log "installing dotfiles"
    arch-chroot /mnt sudo -u "$system_user" bash "$dotfiles_dir/install.sh" || return 1
    arch-chroot /mnt sudo -u "$system_user" touch "$dotfiles_dir/.dotfiles-installed"
    changed=1
  fi

  return $changed
}
