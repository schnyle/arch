# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
hostname="desk$(date '+%Y%m%d')"
system_user="kyle"
git_name="kyle"
email="kylesch115@gmail.com"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
partition_layout=(
  "512M:fat32:/boot"
  "2G:swap:swap"
  ":ext4:/"
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
  pulseaudio
  qutebrowser
  root-password
  ssh-key
  time
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
