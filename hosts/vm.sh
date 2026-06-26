# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
hostname="vm"
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
  alacritty
  # arandr
  avahi
  git
  grub
  gtk
  hostname
  i3
  localization
  minesweeper
  mirrors
  neovim
  ohmyzsh
  # pavucontrol
  # pulseaudio
  qutebrowser
  ssh-key
  time
  tmux
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
  qbittorrent
  qmk
  rsync
  tree
  vim
  virtiofsd
  unzip
  wget
  xclip
)
