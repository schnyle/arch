# alacritty is installed and dotfile

: "${system_user:=}"

pacman_packages=(
  alacritty
)

configure() {
  ensure_dotfile "$(script_dir)/alacritty.toml" "/home/$system_user/.config/alacritty/alacritty.toml"
}
