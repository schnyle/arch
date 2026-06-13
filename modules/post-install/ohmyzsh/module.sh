pacman_packages=(
  git
  zsh
)

# oh-my-zsh is installed.

: "${system_user:=}"

configure() {
  [[ -d "/home/$system_user/.oh-my-zsh" ]] && return 0

  log "installing oh-my-zsh"
  sudo -u "$system_user" bash -c \
    'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  return 1
}
