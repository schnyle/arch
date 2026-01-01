#!/bin/bash

# configuration
BOOT_SIZE="512M"
SWAP_SIZE="2G"
USERNAME="kyle"
HOSTNAME="atlas"

LOG_FILE="/var/log/install.log"
DEBUG_LOG_FILE="/var/log/install-debug.log"

# logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a $LOG_FILE; }

# redirect ouput to verbose log file
if [[ -z "$LOGGING_SETUP" ]]; then
  log "starting Arch installation"
  exec 1> >(tee -a $DEBUG_LOG_FILE)
  exec 2>&1
  export LOGGING_SETUP=1
fi

restartnow() { log "restarting install script" && exec "$(realpath "$0")"; }

CHANGES=0
changed() { ((CHANGES++)); }

if [[ ! -f /var/lib/pacman/sync/core.db ]]; then
  log "initializing pacman"
  pacman -Sy archlinux-keyring --noconfirm
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Sy --noconfirm
  restartnow
fi

# 1. Pre-installation

# 1.8 Update the system clock
if ! timedatectl | grep -q "System clock synchronized: yes"; then
  log "updating system clock"
  timedatectl
  changed
fi

# 1.9 Partition the disks
if ! mountpoint -q /mnt; then
  log "parititoning the disks"

  while true; do
    echo "available devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    echo
    read -r -p "enter device name (omit '/dev/'): " device

    if [[ -b "/dev/$device" ]]; then
      log "selected device: $device"
      break
    else
      echo "device '$device' not found, try again"
    fi
  done

  sfdisk "/dev/$device" <<EOF
label: gpt
,$BOOT_SIZE,U
,$SWAP_SIZE,S
,,L
write
EOF

  if [[ $device =~ nvme ]]; then
    device="${device}p"
  fi

  log "formatting the partitions"
  # 1.10 Format the partitions
  mkfs.fat -F32 "/dev/${device}1"
  mkswap "/dev/${device}2"
  swapon "/dev/${device}2"
  mkfs.ext4 "/dev/${device}3"

  log "mounting the file systems"
  # 1.11 Mount the file systems
  mount "/dev/${device}3" /mnt
  mount --mkdir "/dev/${device}1" /mnt/boot
  changed
fi

# 2. Installation

# 2.2 Install essential packages
# (needs to run before 2.1)
if ! arch-chroot /mnt pacman -Q base linux linux-firmware &>/dev/null; then
  log "installing essential packages"
  pacstrap /mnt base linux linux-firmware sudo
  changed
fi

# 2.1 Select the mirrors
REFLECTOR_CONF_PATH="/mnt/etc/xdg/reflector/reflector.conf"

# install reflector
if ! arch-chroot /mnt pacman -Q reflector &>/dev/null; then
  log "installing reflector"
  arch-chroot /mnt pacman -S --noconfirm reflector
  restartnow
  changed
fi

# configure reflector
if ! (grep -q -- "--latest 10" "$REFLECTOR_CONF_PATH" && grep -q -- "--sort rate" "$REFLECTOR_CONF_PATH"); then
  log "configuring reflector"
  sed -i "s/--latest .*/--latest 10/g" "$REFLECTOR_CONF_PATH"
  sed -i "s/--sort .*/--sort rate/g" "$REFLECTOR_CONF_PATH"
  arch-chroot /mnt systemctl start reflector.service
  changed
fi

# enable timer
if ! arch-chroot /mnt systemctl is-enabled reflector.timer &>/dev/null; then
  log "enabling reflector.timer daemon"
  arch-chroot /mnt systemctl enable reflector.timer
  changed
fi

# 3. Configure the system

# 3.1 Fstab
if [[ ! -s /mnt/etc/fstab ]]; then
  log "generating fstab file"
  genfstab -U /mnt >>/mnt/etc/fstab
  restartnow
fi

# 3.2 Chroot
# (installation runs from live environment)

# 3.3 Time
TIME_ZONE="/usr/share/zoneinfo/America/Denver"
if [[ $(readlink /mnt/etc/localtime) != "$TIME_ZONE" ]]; then
  log "setting the time zone"
  arch-chroot /mnt ln -sf "$TIME_ZONE" /etc/localtime
  changed
fi

arch-chroot /mnt hwclock --systohc || log "[WARNING] failed to set the hardware clock"

# 3.4 Localization

# specify locale to use
if ! grep -q "^en_US.UTF-8 UTF-8" /mnt/etc/locale.gen; then
  log "specifying locale"
  arch-chroot /mnt sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen
  changed
fi

# generate locales
if ! arch-chroot /mnt locale -a | grep -q "en_US.utf8"; then
  log "generating locales"
  arch-chroot /mnt locale-gen
  changed
fi

# create locale.conf and set LANG
if [[ "$(cat /mnt/etc/locale.conf 2>/dev/null)" != "LANG=en_US.UTF-8" ]]; then
  log "creating locale.conf and setting LANG"
  echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
  changed
fi

# 3.5 Network configuration
if [[ "$(cat /mnt/etc/hostname 2>/dev/null)" != "$HOSTNAME" ]]; then
  log "setting hostname to $HOSTNAME"
  echo "$HOSTNAME" >/mnt/etc/hostname
  changed
fi

# 3.6 Initramfs
# (usually not required)

# 3.7 Root password
if ! arch-chroot /mnt passwd -S root | grep -q " P "; then
  log "setting root password"
  arch-chroot /mnt bash -c "passwd"
  changed
fi

# 3.8 Boot loader

if ! arch-chroot /mnt pacman -Q grub efibootmgr os-prober &>/dev/null; then
  log "installing bootloader packages"
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr os-prober
  restartnow
fi

if [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  log "installing GRUB bootloader"
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  changed
fi

if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
  log "configuring GRUB bootloader"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  changed
fi

if [[ ! -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
  log "creating fallback bootloader for picky UEFI implementations"
  arch-chroot /mnt mkdir -p /boot/EFI/BOOT
  arch-chroot /mnt cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
  changed
fi

# 4. Reboot
# (skip reboot - continuing with post-installation)

# 5. Post-installation

# create user and configure sudo
if ! arch-chroot /mnt id "$USERNAME" &>/dev/null; then
  log "creating user $USERNAME"
  arch-chroot /mnt useradd -m -G wheel "$USERNAME"
  restartnow
fi

if ! arch-chroot /mnt passwd -S "$USERNAME" | grep -q " P "; then
  log "setting password for $USERNAME"
  arch-chroot /mnt bash -c "passwd '$USERNAME'"
  changed
fi

if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /mnt/etc/sudoers; then
  log "allowing sudo for wheel group users"
  arch-chroot /mnt sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
  changed
fi

TEMP_SUDOERSD_FILE="/etc/sudoers.d/temp_install"
if ! grep -q "$USERNAME ALL=(ALL) NOPASSWD: ALL" "/mnt$TEMP_SUDOERSD_FILE" &>/dev/null || [[ $(arch-chroot /mnt stat -c "%a" "$TEMP_SUDOERSD_FILE") != "440" ]]; then
  log "configuring temporary passwordless sudo for $USERNAME"
  arch-chroot /mnt bash -c "echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' >$TEMP_SUDOERSD_FILE"
  arch-chroot /mnt chmod 440 "$TEMP_SUDOERSD_FILE"
  restartnow
fi

# install oh-my-zsh and configure shell
if ! arch-chroot /mnt pacman -Q zsh &>/dev/null; then
  log "installing zsh"
  arch-chroot /mnt pacman -S --noconfirm zsh
  restartnow
fi

if ! arch-chroot /mnt pacman -Q git &>/dev/null; then
  log "installing git"
  arch-chroot /mnt pacman -S --noconfirm git
  restartnow
fi

if ! grep "^$USERNAME:" /mnt/etc/passwd | grep -q "/usr/bin/zsh"; then
  log "setting zsh as default shell for $USERNAME"
  arch-chroot /mnt chsh -s /usr/bin/zsh "$USERNAME"
  changed
fi

if [[ ! -d "/mnt/home/$USERNAME/.oh-my-zsh" ]]; then
  log "installing oh-my-zsh"
  arch-chroot /mnt sudo -u "$USERNAME" bash -c "curl -L https://install.ohmyz.sh | sh"
  changed
fi

# install and enable NetworkManager
if ! arch-chroot /mnt pacman -Q networkmanager &>/dev/null; then
  log "installing NetworkManager"
  arch-chroot /mnt pacman -S --noconfirm networkmanager
  restartnow
fi

if ! arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null; then
  log "enabling NetworkManager service"
  arch-chroot /mnt systemctl enable NetworkManager
  changed
fi

# ssh
if ! arch-chroot /mnt pacman -Q openssh &>/dev/null; then
  log "installing openssh"
  arch-chroot /mnt pacman -S --noconfirm openssh
  changed
fi

if ! arch-chroot /mnt systemctl is-enabled sshd &>/dev/null; then
  log "enabling sshd"
  arch-chroot /mnt systemctl enable sshd
  changed
fi

# dns resolution
if ! arch-chroot /mnt pacman -Q avahi &>/dev/null; then
  log "installing avahi"
  arch-chroot /mnt pacman -S --noconfirm avahi
  changed
fi

if ! arch-chroot /mnt systemctl is-enabled avahi-daemon; then
  log "enabling avahi-daemon"
  arch-chroot /mnt systemctl enable avahi-daemon
  changed
fi

# firewall
if ! arch-chroot /mnt pacman -Q ufw &>/dev/null; then
  log "installing ufw"
  arch-chroot /mnt pacman -S --noconfirm ufw
  restartnow
fi

# Disable IPv6 to avoid kernel module issues during install
# This is due to kernel difference in live env and bootable device
# Will want to remedy this at some point - perhaps moving the actual
# user setup portion of install to
if ! grep -q "^IPV6=no" /mnt/etc/default/ufw; then
  log "ufw: disabling IPv6"
  arch-chroot /mnt sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
  changed
fi

if ! arch-chroot /mnt ufw status verbose | grep -q "deny (incoming)"; then
  log "ufw: setting default deny incoming"
  arch-chroot /mnt ufw default deny incoming
  changed
fi

if ! arch-chroot /mnt ufw status verbose | grep -q "allow (outgoing)"; then
  log "ufw: setting default allow outgoing"
  arch-chroot /mnt ufw default allow outgoing
  changed
fi

if ! arch-chroot /mnt ufw status verbose | grep -q "22/tcp.*ALLOW"; then
  log "ufw: allowing TCP on port 22"
  arch-chroot /mnt ufw allow 22/tcp
  changed
fi

if ! arch-chroot /mnt ufw status | grep -q "Status: active"; then
  log "ufw: enabling firewall"
  arch-chroot /mnt ufw --force enable
  restartnow
fi

# fail2ban
if ! arch-chroot /mnt pacman -Q fail2ban &>/dev/null; then
  log "installing fail2ban"
  arch-chroot /mnt pacman -S --noconfirm fail2ban
  restartnow
fi

if [[ ! -f /mnt/etc/fail2ban/jail.local ]]; then
  log "fail2ban: creating jail.local config"
  cat >/mnt/etc/fail2ban/jail.local <<"EOF"
[DEFAULT]
# ban for 10 minutes
bantime = 10m

# check for failures in last 10 minutes
findtime = 10m

# ban after 5 failures
maxretry = 5

# use ufw for banning
banaction = ufw

# use systemd journal instead of log files
backend = systemd

[sshd]
enabled = true
port = 22
EOF
  changed
fi

if ! arch-chroot /mnt systemctl is-enabled fail2ban &>/dev/null; then
  log "fail2ban: enabling service"
  arch-chroot /mnt systemctl enable fail2ban
  changed
fi

# clean up

# copy log files
if [[ ! -f "/mnt$LOG_FILE" ]] || [[ ! -f "/mnt$DEBUG_LOG_FILE" ]]; then
  log "copying log files to target system"
  cp "$LOG_FILE" "/mnt$LOG_FILE"
  cp "$DEBUG_LOG_FILE" "/mnt$DEBUG_LOG_FILE"
  changed
fi

if [[ "$CHANGES" -gt 0 ]]; then
  log "restarting to verify $CHANGES changes"
  exec "$0"
fi

for i in {1..3}; do
  if [[ ! -f "/mnt$TEMP_SUDOERSD_FILE" ]]; then
    break
  fi

  log "removing temporary passwordless sudo file"
  rm "/mnt$TEMP_SUDOERSD_FILE"
  sleep 1
done

if [[ -f "/mnt$TEMP_SUDOERSD_FILE" ]]; then
  log "WARNING: failed to remove $TEMP_SUDOERSD_FILE. Remove manually, then reboot the system."
  exit
fi

log "installation completed successfully"
reboot
