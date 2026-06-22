: "${system_user:=}"

pacman_packages=(
  qutebrowser
)

configure() {
  ensure_dotfile "$(script_dir)/config.py" "/home/$system_user/.config/qutebrowser/config.py"
}
