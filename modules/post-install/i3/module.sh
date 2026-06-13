: "${system_user:=}"

pacman_packages=(
  alacritty
  i3-wm
  i3blocks
  i3lock
  i3status
  picom
  xorg-server
  xorg-xinit
  xorg-xset
)

configure() {
  ensure_dotfile "$(script_dir)/i3_config" "/home/$system_user/.config/i3/config"
  ensure_dotfile "$(script_dir)/i3status_config" "/home/$system_user/.config/i3status/config"
  ensure_dotfile "$(script_dir)/.xinitrc" "/home/$system_user/.xinitrc"
}
