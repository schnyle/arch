: "${system_user:=}"

oh_my_zsh_pacman_packages=(
  git
  zsh
)
add_pacman_packages "${oh_my_zsh_pacman_packages[@]}"

configure_oh_my_zsh() {
  require_var system_user

  [[ -d "/mnt/home/$system_user/.oh-my-zsh" ]] && return 0

  log "installing oh-my-zsh"
  arch-chroot /mnt sudo -u "$system_user" bash -c \
    'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  return 1
}
