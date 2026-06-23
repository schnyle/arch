: "${system_user:=}"

pacman_packages=(
  picom
)

configure() {
  ensure_dotfile "$(script_dir)/picom.conf" "/home/$system_user/.config/picom.conf"
}
