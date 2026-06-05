: "${system_user:=}"

dotfiles_pacman_packages=(
  git
  stow
)
add_pacman_packages "${dotfiles_pacman_packages[@]}"

configure_dotfiles() {
  require_var system_user

  local changed=0

  if [[ ! -d "/mnt/home/$system_user/.dotfiles" ]]; then
    log "cloning dotfiles repository"
    arch-chroot /mnt sudo -u "$system_user" git clone https://github.com/schnyle/dotfiles.git "/home/$system_user/.dotfiles"
    changed=1
  fi

  if [[ ! -f "/mnt/home/$system_user/.dotfiles-installed" ]]; then
    log "installing dotfiles"
    arch-chroot /mnt sudo -u "$system_user" bash "/home/$system_user/.dotfiles/install.sh" || return 1
    arch-chroot /mnt sudo -u "$system_user" touch "/home/$system_user/.dotfiles-installed"
  fi

  return $changed
}
