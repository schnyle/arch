#!/bin/bash

# configuration
BOOT_SIZE="512M"
SWAP_SIZE="2G"
USERNAME="kyle"

# logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a /var/log/install.log; }

# redirect ouput to verbose log file
if [[ -z "$LOGGING_SETUP" ]]; then
  exec 1> >(tee -a /var/log/install-debug.log)
  exec 2>&1
  export LOGGING_SETUP=1
fi

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
  pacstrap /mnt base linux linux-firmware sudo
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
if ! (grep -q -- "--latest 10" "$REFLECTOR_CONF_PATH" && grep -q -- "--sort rate" "$REFLECTOR_CONF_PATH"); then
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

# 5. Post-installation

# 5.1 user setup

# create user and configure sudo
if ! arch-chroot /mnt id "$USERNAME" &>/dev/null; then
  log "creating user $USERNAME"
  arch-chroot /mnt useradd -m -G wheel "$USERNAME"
  restart
fi

if arch-chroot /mnt passwd -S "$USERNAME" | grep -q " NP "; then
  log "setting password for $USERNAME"
  arch-chroot /mnt passwd "$USERNAME"
fi

if ! grep -q "%wheel ALL=(ALL:ALL) ALL" /mnt/etc/sudoers; then
  log "allowing sudo for wheel group users"
  arch-chroot /mnt sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
fi

if ! grep -q "$USERNAME ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers.d/temp_install; then
  log "configuring temporary passwordless sudo for $USERNAME"
  arch-chroot /mnt bash -c "echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/temp_install"
  restart
fi

if [[ $(arch-chroot /mnt stat -c "%a" /etc/sudoers.d/temp_install) != "440" ]]; then
  log "setting file permissions for temporary passwordless sudo"
  arch-chroot /mnt chmod 440 /etc/sudoers.d/temp_install
fi

# install oh-my-zsh and configure shell
if ! arch-chroot /mnt pacman -Q zsh &>/dev/null; then
  log "installing zsh"
  arch-chroot /mnt pacman -S --noconfirm zsh
  restart
fi

if ! arch-chroot /mnt pacman -Q git &>/dev/null; then
  log "installing git"
  arch-chroot /mnt pacman -S --noconfirm git
  restart
fi

if ! grep "^$USERNAME:" /mnt/etc/passwd | grep -q "/mnt/usr/bin/zsh"; then
  log "setting zsh as default shell for $USERNAME"
  arch-chroot /mnt chsh -s /usr/bin/zsh "$USERNAME"
fi

if [[ ! -d "/mnt/home/$USERNAME/.oh-my-zsh" ]]; then
  log "installing oh-my-zsh"
  arch-chroot /mnt sudo -u "$USERNAME" bash -c "curl -L https://install.ohmyz.sh | sh"
fi

# install pulse audio and configure service
if ! arch-chroot /mnt pacman -Q pulseaudio &>/dev/null; then
  log "installing pulseaudio"
  arch-chroot /mnt pacman -S --noconfirm pulseaudio
fi

if [[ ! -d "/mnt/home/$USERNAME/.config/systemd/user/default.target.wants" ]]; then
  log "creating pulseaudio systemd directory"
  arch-chroot /mnt mkdir -p "/home/$USERNAME/.config/systemd/user/default.target.wants"
  restart
fi

SYMLINK="/home/$USERNAME/.config/systemd/user/default.target.wants/pulseaudio.service"
TARGET="/usr/lib/systemd/user/pulseaudio.service"
if [[ $(arch-chroot /mnt readlink "$SYMLINK" 2>/dev/null) != "$TARGET" ]]; then
  log "enabling pulseaudio user service"
  arch-chroot /mnt ln -sf "$TARGET" "$SYMLINK"
fi

if find "/mnt/home/$USERNAME/.config" ! -user "$USERNAME" -o ! -group "$USERNAME" | grep -q .; then
  log "setting .config/ directory ownership"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
fi

# install Arch User Repository helper (yay)
if ! arch-chroot /mnt pacman -Q base-devel &>/dev/null; then
  log "installing base-devel"
  arch-chroot /mnt pacman -S --noconfirm base-devel
  restart
fi

if [[ ! -d /mnt/opt/yay/.git ]]; then
  log "cloning yay"
  arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /opt/yay
  restart
fi

if find /mnt/opt/yay ! -user "$USERNAME" -o ! -group "$USERNAME" | grep -q .; then
  log "setting yay directory ownership"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" /opt/yay
fi

if ! arch-chroot /mnt which yay &>/dev/null; then
  log "building and installing yay"
  arch-chroot /mnt sudo -u "$USERNAME" makepkg -si -D /opt/yay --noconfirm
fi

# rest of installation

if [[ -f /mnt/etc/sudoers.d/temp_install ]]; then
  log "deleting temporary file for passwordless sudo"
  rm /mnt/etc/sudoers.d/temp_install
fi
