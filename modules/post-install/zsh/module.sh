pacman_packages=(
  zsh
)

# zsh is installed and set as default shell.

: "${system_user:=}"

configure() {
  grep "^$system_user:" /etc/passwd | grep -q "/usr/bin/zsh" && return 0

  log "setting zsh as default shell for $system_user"
  chsh -s /usr/bin/zsh "$system_user"
  return 1
}
