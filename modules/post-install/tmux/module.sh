# tmux is installed and configured

: "${system_user:=}"

pacman_packages=(
  tmux
)

configure() {
  ensure_dotfile "$(script_dir)/.tmux.conf" "/home/$system_user/.tmux.conf"
}
