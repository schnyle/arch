# zsh is installed and set as default shell.

: "${system_user:=}"

pacman_packages=(
  zsh
)

configure() {
  ensure_dotfile "$(script_dir)/.zshrc" "/home/$system_user/.zshrc"

  grep "^$system_user:" /etc/passwd | grep -q "/usr/bin/zsh" && return 0

  log "setting zsh as default shell for $system_user"
  chsh -s /usr/bin/zsh "$system_user"
  return 1
}
