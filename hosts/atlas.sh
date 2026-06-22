# shellcheck disable=SC2034

hostname="atlas$(date '+%Y%m%d')"
ssh_port=2222
system_user="atlas"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
time_zone="/usr/share/zoneinfo/America/Denver"
partition_layout=(
  "512M:fat32:/boot"
  "2G:swap:swap"
  "32G:ext4:/"
  ":ext4:/storage"
)

modules=(
  root-password
  user
  home-dirs
  atlas
  avahi
  fail2ban
  grub
  hostname
  localization
  mirrors
  networkmanager
  sshd
  time
  ufw
)

pacman_packages=(
  inetutils
  less
  man-db
  rsync
  tree
  vim
  xclip
)
