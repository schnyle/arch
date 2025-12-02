#!/bin/bash

# configuration
BOOT_SIZE="512M"
SWAP_SIZE="2G"

# logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a /var/log/install.log; }

# redirect ouput to verbose log file
exec 1> >(tee -a /var/log/install-debug.log)
exec 2> >(tee -a /var/log/install-debug.log >&2)

restart() { log "restarting install script" && exec "$0"; }

if ! (grep -q "^\[multilib\]" /etc/pacman.conf && grep -q "^Include = /etc/pacman.d/mirrorlist" /etc/pacman.conf); then
  log "enabling 32-bit libraries"
  sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /etc/pacman.conf
fi

if [[ ! -f /var/lib/pacman/sync/core.db ]]; then
  log "initializing pacman"
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Sy --noconfirm
  restart
fi

# 1. Pre-installation

# 1.8 Update the system clock
if ! timedatectl | grep -q "System clock synchronized: yes"; then
  log "updating system clock"
  timedatectl
fi

if ! mountpoint -q /mnt; then
  log "parititoning the disks"
  # 1.9 Partition the disks
  sfdisk "/dev/vda" <<EOF
label: gpt
,$BOOT_SIZE,U
,$SWAP_SIZE,S
,,L
write
EOF

  log "formatting the partitions"
  # 1.10 Format the partitions
  mkfs.fat -F32 /dev/vda1
  mkswap /dev/vda2
  swapon /dev/vda2
  mkfs.ext4 /dev/vda3

  log "mounting the file systems"
  # 1.11 Mount the file systems
  mount /dev/vda3 /mnt
  mount --mkdir /dev/vda1 /mnt/boot
fi

# 2. Installation

# 2.2 Install essential packages
# (needs to run before 2.1)
if ! arch-chroot /mnt pacman -Q base linux linux-firmware &>/dev/null; then
  log "installing essential packages"
  pacstrap /mnt base linux linux-firmware
fi

# 2.1 Select the mirrors
REFLECTOR_CONF_PATH="/mnt/etc/xdg/reflector/reflector.conf"

# install reflector
if ! arch-chroot /mnt pacman -Q reflector &>/dev/null; then
  log "installing reflector"
  arch-chroot /mnt pacman -S --noconfirm reflector
  restart
fi

# configure reflector
if ! (grep -q "--latest 10" "$REFLECTOR_CONF_PATH" && grep -q "--sort rate" "$REFLECTOR_CONF_PATH"); then
  log "configuring reflector"
  sed -i "s/--latest .*/--latest 10/g" "$REFLECTOR_CONF_PATH"
  sed -i "s/--sort .*/--sort rate/g" "$REFLECTOR_CONF_PATH"
  arch-chroot /mnt systemctl start reflector.service
fi

# enable timer
if ! arch-chroot /mnt systemctl is-enabled reflector.timer &>/dev/null; then
  log "enabling reflector.timer daemon"
  arch-chroot /mnt systemctl enable reflector.timer
fi

# 3. Configure the system

# 3.1 Fstab
if [[ ! -s /mnt/etc/fstab ]]; then
  log "generating fstab file"
  genfstab -U /mnt >>/mnt/etc/fstab
  restart
fi

# 3.2 Chroot
# (installation runs from live environment)

# 3.3 Time
TIME_ZONE="/usr/share/zoneinfo/America/Denver"
if [[ $(readlink /mnt/etc/localtime) != "$TIME_ZONE" ]]; then
  log "setting the time zone"
  arch-chroot /mnt ln -sf "$TIME_ZONE" /etc/localtime
fi

arch-chroot /mnt hwclock --systohc || log "[WARNING] failed to set the hardware clock"

# 3.4 Localization

# specify locale to use
if ! grep -q "^en_US.UTF-8 UTF-8" /mnt/etc/locale.gen; then
  log "specifying locale"
  arch-chroot /mnt sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen
fi

# generate locales
if ! arch-chroot /mnt locale -a | grep -q "en_US.utf8"; then
  log "generating locales"
  arch-chroot /mnt locale-gen
fi

# create locale.conf and set LANG
if [[ "$(cat /mnt/etc/locale.conf 2>/dev/null)" != "LANG=en_US.UTF-8" ]]; then
  log "creating locale.conf and setting LANG"
  echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
fi

# 3.5 Network configuration
HOSTNAME="arch-$(date '+%Y%m%d')"
if [[ "$(cat /mnt/etc/hostname 2>/dev/null)" != "$HOSTNAME" ]]; then
  log "setting hostname to $HOSTNAME"
  echo "$HOSTNAME" >/mnt/etc/hostname
fi

# 3.6 Initramfs
# (usually not required)

# 3.7 Root password
if ! arch-chroot /mnt passwd -S root | grep -q " P "; then
  log "setting root password"
  arch-chroot /mnt bash -c "passwd"
fi

# 3.8 Boot loader

if ! arch-chroot /mnt pacman -Q grub efibootmgr os-prober &>/dev/null; then
  log "installing bootloader packages"
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr os-prober
  restart
fi

if [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  log "installing GRUB bootloader"
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
fi

if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
  log "configuring GRUB bootloader"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi

# 4. Reboot
# (skip reboot - continuing with post-installation)
