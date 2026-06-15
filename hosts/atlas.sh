# shellcheck disable=SC2034

is_live_env=1
boot_size="512M"
swap_size="2G"
root_size="32G"
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="atlas$(date '+%Y%m%d')"
system_user="atlas"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
ssh_port=2222

install_modules=(
  atlas-partitions
  atlas-filesystems
  atlas-mounts
  atlas-snapshot-device
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
  avahi
  networkmanager
  atlas-snapshot
  atlas-storage-dirs
  fail2ban
  sshd
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
