# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
hostname="desk"
system_user="kyle"
git_name="kyle"
email="kylesch115@gmail.com"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
disk_layout=(
  "512M:fat32:/boot"
  "2G:swap:swap"
  ":ext4:/"
)

modules=(
  root-password
  user
  home-dirs
  networkmanager
  # yay
  alacritty
  arandr
  avahi
  desk-displays
  git
  grub
  gtk
  hostname
  i3
  latex
  localization
  minesweeper
  mirrors
  neovim
  # nvidia
  ohmyzsh
  pavucontrol
  # picom
  poe
  pulseaudio
  qutebrowser
  ssh-key
  time
  tmux
  # virtualization
  xorg
  zsh
)

pacman_packages=(
  alsa-utils
  bitwarden
  cmake
  inetutils
  less
  man-db
  openssh
  qbittorrent
  qmk
  rsync
  sof-firmware
  tree
  vim
  virtiofsd
  unzip
  wget
  xclip
)
