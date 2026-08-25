: "${system_user:=}"

pacman_packages=(
  alacritty
  ttf-jetbrains-mono-nerd
)

configure() {
  ensure_dotfile "$(script_dir)/alacritty.toml" "/home/$system_user/.config/alacritty/alacritty.toml"
}
