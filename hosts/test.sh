# shellcheck disable=SC2034

is_live_env=1
boot_size="512M"
swap_size="2G"
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="desk$(date '+%Y%m%d')"
system_user="kyle"
git_name="kyle"
email="kylesch115@gmail.com"
temp_sudoersd_file="/etc/sudoers.d/temp_install"

post_install_modules=(
  user
  home-dirs
  networkmanager
  neovim
  xserver
  i3
  # yay
  # # nvidia
  # ohmyzsh
  # # virtualization
  # compositor
  # minesweeper
  # git
  # zsh
  # pulseaudio
  # dotfiles
  # ssh-key
  # desk-displays
  # gtk
  # pavucontrol
  # arandr
  dotfiles
)
