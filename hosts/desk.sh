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

install_modules=(
  partitions
  filesystems
  mounts
  essential-packages
  multilib
  mirrors
  fstab
  time
  localization
  hostname
  root_password
  bootloader
)

post_install_modules=(
  user
  home-dirs
  networkmanager
  yay
  # nvidia
  ohmyzsh
  # virtualization
  compositor
  minesweeper
  git
  zsh
  pulseaudio
  dotfiles
  ssh-key
  desk-displays
  gtk
  pavucontrol
  arandr
  latex
  i3
)

pacman_packages=(
  adobe-source-code-pro-fonts
  alacritty
  alsa-utils
  bitwarden
  cmake
  inetutils
  less
  man-db
  neovim
  npm
  openssh
  qmk
  qutebrowser
  rsync
  sof-firmware
  tmux
  tree
  vi
  vim
  xorg-server
  xorg-xinit
  xorg-xset
  unzip
  wget
  xclip

)
