# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
hostname="bare"
system_user="kyle"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
disk_layout=(
  "512M:fat32:/boot"
  "2G:swap:swap"
  ":ext4:/"
)

modules=(
  root-password
  user
  networkmanager
  grub
  hostname
  localization
  mirrors
  time
)

pacman_packages=(
)
