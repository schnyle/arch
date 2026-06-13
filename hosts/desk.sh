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
  alacritty
  arandr
  desk-displays
  git
  gtk
  i3
  latex
  minesweeper
  neovim
  # nvidia
  ohmyzsh
  pavucontrol
  # picom
  pulseaudio
  qutebrowser
  ssh-key
  tmux
  # virtualization
  xorg
  zsh
)

pacman_packages=(
  adobe-source-code-pro-fonts
  alsa-utils
  bitwarden
  cmake
  inetutils
  less
  man-db
  openssh
  qmk
  rsync
  sof-firmware
  tree
  vi
  vim
  virtiofsd
  unzip
  wget
  xclip
)
