# shellcheck disable=SC2034

boot_size="512M"
swap_size="2G"
root_size="32G"
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="atlas$(date '+%Y%m%d')"
system_user="atlas"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
ssh_port=2222

post_install_modules=(
  atlas-snapshot
  atlas-storage-dirs
  avahi
  fail2ban
  grub
  home-dirs
  hostname
  localization
  mirrors
  networkmanager
  root-password
  snapshot-device
  sshd
  time
  ufw
  user
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
