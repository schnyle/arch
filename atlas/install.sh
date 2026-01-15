#!/bin/bash

# ========
# 0. Setup
# ========

# 0.1 Installation configuration
# --------------------------

# 0.1.1 User
system_user="kyle"

# 0.1.2 System
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="arch-$(date '+%Y%m%d')"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
boot_part_size="512M"
swap_size="2G"
ssh_port=2222

# 0.1.3 Script
log_file="/var/log/install.log"
debug_log_file="/var/log/install-debug.log"

# 0.2 Software lists
# ------------------

# 0.2.1 Core packages
# Always installed
core_packages=(
  avahi          # Service Discovery for Linux using mDNS/DNS-SD (compatible with Bonjour)
  fail2ban       # bans IPs after too many failed authentication attempts
  git            # the fast distributed version control system
  inetutils      # a collection of common network programs
  networkmanager # network connection manager and user application
  openssh        # SSH protocol implementation for remote login, command execution and file transfer
  ufw            # Uncomplicated and easy to use CLI tool for managing a netfilter firewall
  vim            # Vi Improved, a highly configurable, improved version of the vi text editor
)

# 0.3 Function definitions
# ------------------------

# 0.3.1 Logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a $log_file; }

# 0.3.2 Redirect stdout to log file
if [[ -z "$LOGGING_SETUP" ]]; then
  log "starting Arch installation"
  exec 1> >(tee -a $debug_log_file)
  exec 2>&1
  export LOGGING_SETUP=1
fi

# 0.3.3 Immediate script restart
restartnow() { log "restarting install script" && exec "$(realpath "$0")"; }

# 0.3.4 Track changes made
changes=0
changed() { ((changes++)); }

# 0.4 Initialize pacman
# Ensures pacman is initialized for the live insallation
if [[ ! -f /var/lib/pacman/sync/core.db ]]; then
  log "initializing pacman"
  pacman -Sy archlinux-keyring --noconfirm
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Sy --noconfirm
  restartnow
fi

# ===================
# 1. Pre-installation
# ===================

# Steps 1.1 - 1.7 are assumed to already be completed.

# 1.1 Acquire and installation image
# ----------------------------------
#
# 1.2 Verify signature
# --------------------
#
# 1.3 Prepare an installation medium
# ----------------------------------
#
# 1.4 Boot the live environment
# -----------------------------
#
# 1.5 Set the console keyboard layout and font
# --------------------------------------------
#
# 1.6 Verify the boot mode
# ------------------------
#
# 1.7 Connect to the internet
# ---------------------------

# 1.8 Update the system clock
# ---------------------------
# The live system needs accurate time to prevent package signature verification failures and TLS certificate errors.
# The systemd-timesyncd service is enabled by default in the live environment and time will be synchronized
# automatically once a connection to the internet is established.
# Use timedatectl to ensure the system clock is synchronized.

if ! timedatectl | grep -q "System clock synchronized: yes"; then
  log "updating system clock"
  timedatectl
  changed
fi

# Steps 1.9 - 1.11 are conditional and executed as one logical thread.

# 1.9 Partition the disks
# -----------------------
# The following partitions are required for a chosen device:
#     - One partition for the root directory /.
#     - For booting in UEFI mode: an EFI system partition.
#
# This step will only run if no device is mounted to the live environment. The user will be
# prompted to choose a device and warned if existing partitions are found. If the user
# chooses to overwrite those partitions, filesystem signatures will be cleared before new partitioning is applied.
# Any existing EFI boot entries pointing to the device are also removed to prevent orphaned UEFI entries.
# This script creates a GPT partition table with the following partitions:
#     - boot: UEFI system partition (ESP)
#     - swap: Linux swap partition
#     - root: Linux filesystem partition
#
# 1.9.1 Get install device from user
# 1.9.2 Check for existing device partitions
# 1.9.3 Remove any EFI boot entries pointing to install device
# 1.9.4 Wipe signatures from install device
# 1.9.5 Create new partitions on install device
#
# 1.10 Format the partitions
# --------------------------
# Once the partitions have been created, each newly created partition must be formatted with an appropriate file system.
# This script uses the following file system formats:
#     - boot: FAT32
#     - swap: swap
#     - root: ext4
#
# 1.11 Mount the file systems
# ---------------------------
# Mount the volumes in the following order:
#     - root: to /mnt
#     - boot: to /mnt/boot
#     - swap: enable with swapon
#
# Note about boot loaders:
# Step 3.8 Boot loader creates a new bootloader only if one is not already found. Therefore, if a new Arch install is
# installed onto a device which already has a bootloader, that bootloader will be removed to prevent
# identifying a bootloader which points to a partition that no longer exists.

if ! mountpoint -q /mnt; then
  log "partitioning the disks"

  # get install device from user
  while true; do
    echo "available devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    echo
    read -r -p "enter device name (omit '/dev/'): " install_device
    install_device="/dev/$install_device"

    if [[ -b "$install_device" ]]; then
      log "selected device: $install_device"
      break
    else
      echo "device '$install_device' not found, try again"
    fi
  done

  # check if device has partitions and cleanup
  if lsblk -n "$install_device" | grep -q part; then
    echo "WARNING: this will destroy all data on $install_device"
    lsblk "$install_device"
    read -r -p "Continue? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && exit 1

    # remove any EFI boot entries pointing to this device to prevent orphaned UEFI entries
    while read -r boot_entry; do
      boot_num=$(echo "$boot_entry" | grep -oP "^Boot\K[0-9]{4}")

      uuid=$(echo "$boot_entry" | grep -oP "[a-f0-9-]{36}")
      [[ -z "$uuid" ]] && continue

      boot_device=$(blkid | grep -i "$uuid" | cut -d: -f1)
      [[ -z "$boot_device" ]] && continue

      if [[ "$boot_device" =~ ^${install_device} ]]; then
        log "removing boot entry $boot_num"
        efibootmgr -b "$boot_num" -B
      fi
    done < <(efibootmgr -v | grep -E "^Boot[0-9]{4}")

    wipefs -a "$install_device"
  fi

  sfdisk "$install_device" <<EOF
label: gpt
,$boot_part_size,U
,$swap_size,S
,,L
write
EOF

  # NVMe drives use 'p' separator for partition numbers (e.g., /dev/nvme0n1p1)
  if [[ $install_device =~ nvme ]]; then
    install_device="${install_device}p"
  fi

  log "formatting the partitions"
  mkfs.fat -F32 "${install_device}1"
  mkswap "${install_device}2"
  mkfs.ext4 "${install_device}3"

  log "mounting the file systems"
  mount "${install_device}3" /mnt
  mount --mkdir "${install_device}1" /mnt/boot
  swapon "${install_device}2"
  changed
fi

# ==============
# 2. Installation
# ==============

# Note: Steps 2.2 and 2.1 are intentionally reversed from the Arch Installation Guide.
# This is required because 2.1 uses arch-chroot commands which need the base system to exist first.

# 2.2 Install essential packages
# ------------------------------
# Use pacstrap to install the base system into /mnt. This creates the chroot environment
# that subsequent arch-chroot commands depend on.
# No configuration (except for /etc/pacman.d/mirrorlist) gets carried over from the live environment to the
# installed system. The only mandatory package to install is base, which does not include all tools from the
# live installation, so installing more packages is frequently necessary.
# pacstrap packages installed:
#     - base:           minimal package set to define a basic Arch Linux installation
#     - linux:          the Linux kernel and modules
#     - linux-firmware: firmware files for Linux - Default set
#     - sudo:           give certain users the ability to run some commands as root

if ! arch-chroot /mnt pacman -Q base linux linux-firmware &>/dev/null; then
  log "installing essential packages"
  pacstrap /mnt base linux linux-firmware sudo
  restartnow # 2.1 requires the chroot environment
fi

# 2.1 Select the mirrors
# ----------------------
# Configure reflector to automatically select the fastest mirrors for the installed system.
# This step requires the chroot environment created by step 2.2 to function properly.

reflector_conf="/mnt/etc/xdg/reflector/reflector.conf"

# 2.1.1 Install reflector
if ! arch-chroot /mnt pacman -Q reflector &>/dev/null; then
  log "installing reflector"
  arch-chroot /mnt pacman -S --noconfirm reflector
  changed
fi

# 2.1.2 Configure reflector
# Configure reflector with the following settings:
# - 10 latest mirrors
# - sort by download rate
if ! (grep -q -- "--latest 10" "$reflector_conf" && grep -q -- "--sort rate" "$reflector_conf"); then
  log "configuring reflector"
  sed -i "s/--latest .*/--latest 10/g" "$reflector_conf"
  sed -i "s/--sort .*/--sort rate/g" "$reflector_conf"
  arch-chroot /mnt systemctl start reflector.service
  changed
fi

# 2.1.3 Enable timer so reflector regularly regenerates mirrors (weekly)
if ! arch-chroot /mnt systemctl is-enabled reflector.timer &>/dev/null; then
  log "enabling reflector.timer daemon"
  arch-chroot /mnt systemctl enable reflector.timer
  changed
fi

# =======================
# 3. Configure the system
# =======================

# 3.1 Fstab
# ---------
# To get needed file systems (like the one used for the boot directory /boot ) mounted on startup,
# Use -U for UUID-based identification instead of device names for better reliability.

if ! grep -q "^UUID=" /mnt/etc/fstab; then
  log "generating fstab file"
  genfstab -U /mnt >>/mnt/etc/fstab
  changed
fi

# 3.2 Chroot
# ----------
# To directly interact with the new system's environment tools, and configurations for the next steps
# as if you were booted into it, change root into the new system.
# This script performs all steps from the live installation medium using `arch-chroot /mnt` commands.

# 3.3 Time
# --------
# For human convenience (e.g. showing the correct local time or handling Daylight Saving Time), set the time zone:

# 3.3.1 Set the time zone
if [[ $(readlink /mnt/etc/localtime) != "$time_zone" ]]; then
  log "setting the time zone"
  ln -sf "$time_zone" /mnt/etc/localtime
  changed
fi

# 3.3.2 Synchronize system and hardware clocks
arch-chroot /mnt hwclock --systohc || log "[WARNING] failed to set the hardware clock"

# 3.3.3 Enable NTP time synchronization
if ! arch-chroot /mnt systemctl is-enabled systemd-timesyncd &>/dev/null; then
  log "enabling systemd-timesyncd"
  arch-chroot /mnt systemctl enable systemd-timesyncd
  changed
fi

# 3.4 Localization
# ----------------
# To use the correct region and language specific formatting (like dates, currency, decimal separators),
# edit /etc/locale.gen and uncomment the desired UTF-8 locales. Then generate the locales with `locale-gen`.
# Create the locale.conf file, and set the LANG variable accordingly.

# 3.4.1 Enable en_US.UTF-8 locale
if ! grep -q "^en_US.UTF-8 UTF-8" /mnt/etc/locale.gen; then
  log "specifying locale"
  sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /mnt/etc/locale.gen
  changed
fi

# 3.4.2 Generate locales
if ! arch-chroot /mnt locale -a | grep -q "en_US.utf8"; then
  log "generating locales"
  arch-chroot /mnt locale-gen
  changed
fi

# 3.4.3 Create locale.conf and set LANG
if [[ "$(cat /mnt/etc/locale.conf 2>/dev/null)" != "LANG=en_US.UTF-8" ]]; then
  log "creating locale.conf and setting LANG"
  echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
  changed
fi

# 3.5 Network configuration
# -------------------------
# To assign a consistent, identifiable name to the system (particularly useful in a networked environment),
# create the hostname file:

if [[ "$(cat /mnt/etc/hostname 2>/dev/null)" != "$hostname" ]]; then
  log "setting hostname to $hostname"
  echo "$hostname" >/mnt/etc/hostname
  changed
fi

# 3.6 Initramfs
# -------------
# Creating a new initramfs is usually not required, because mkinitcpio was run on installation of the
# kernel package with pacstrap (step 2.2).

# 3.7 Root password
# -----------------
# Set a secure password for the root user to allow performing administrative actions:

if ! arch-chroot /mnt passwd -S root | grep -q " P "; then
  log "setting root password"
  arch-chroot /mnt bash -c "passwd"
  changed
fi

# 3.8 Boot loader
# ---------------
# Install and configure GRUB bootloader for UEFI systems.
# Only install if no existing GRUB installation is detected to avoid conflicts.

grub_bootloader_exists=$(
  efibootmgr -v | grep -q "grubx64.efi"
  echo $?
)

# 3.8.1 Install boot loader packages
# grub:       GNU GRand Unified Bootloader
# efibootmgr: Linux user-space application to modify the EFI Boot Manager
# os-prober:  utility to detect other OSes on a set of drives
if ! arch-chroot /mnt pacman -Q grub efibootmgr os-prober &>/dev/null; then
  log "installing bootloader packages"
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr os-prober
  restartnow
fi

# 3.8.2 Install GRUB to EFI system partition
if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  log "installing GRUB bootloader"
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  changed
fi

# 3.8.3 Generate the GRUB configuration file
if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
  log "configuring GRUB bootloader"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  changed
fi

# 3.8.4 Create fallback bootloader for non-compliant UEFI implementations.
# Some motherboards/UEFI firmware ignore custom boot entries and only look for the default
# bootloader path /EFI/BOOT/BOOTX64.EFI. This creates a fallback copy of GRUB at that location
# to ensure the system can boot even on such hardware.
if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
  log "creating fallback bootloader for picky UEFI implementations"
  mkdir -p /mnt/boot/EFI/BOOT
  cp /mnt/boot/EFI/GRUB/grubx64.efi /mnt/boot/EFI/BOOT/BOOTX64.EFI
  changed
fi

# =========
# 4. Reboot
# =========
# Exit the chroot environment and optionally manually unmount all partitions.
# This script skips this step and proceeds to 5. Post-installation.

# ====================
# 5. Post-installation
# ====================

# 5.1 System preparation
# ---------------------

# 5.1.1 User setup

# 5.1.1.1 Create user
if ! arch-chroot /mnt id "$system_user" &>/dev/null; then
  log "creating user $system_user"
  arch-chroot /mnt useradd -m -G wheel "$system_user"
  restartnow
fi

# 5.1.1.2 Set password
if ! arch-chroot /mnt passwd -S "$system_user" | grep -q " P "; then
  log "setting password for $system_user"
  arch-chroot /mnt bash -c "passwd '$system_user'"
  changed
fi

# 5.1.1.3 Allow sudo for wheel group users
if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /mnt/etc/sudoers; then
  log "allowing sudo for wheel group users"
  arch-chroot /mnt sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
  changed
fi

# 5.1.1.4 Setup temporary passwordless sudo for user
# Create a temporary file which allows the user to run sudo commands without password prompt.
# Removed at the end of the installation.
if ! grep -q "$system_user ALL=(ALL) NOPASSWD: ALL" "/mnt$temp_sudoersd_file" &>/dev/null || [[ $(arch-chroot /mnt stat -c "%a" "$temp_sudoersd_file") != "440" ]]; then
  log "configuring temporary passwordless sudo for $system_user"
  arch-chroot /mnt bash -c "echo '$system_user ALL=(ALL) NOPASSWD: ALL' >$temp_sudoersd_file"
  arch-chroot /mnt chmod 440 "$temp_sudoersd_file"
  restartnow
fi

# 5.2 Software installation
# -------------------------

# 5.2.1 Core pacman packages
for pkg in "${core_packages[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
    log "installing core pacman package $pkg"
    arch-chroot /mnt pacman -S --noconfirm "$pkg"
    changed
  fi
done

# 5.3 Configuration

# 5.3.1 Enable NetworkManager service
if ! arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null; then
  log "enabling NetworkManager service"
  arch-chroot /mnt systemctl enable NetworkManager
  changed
fi

# 5.3.2 Configure and enable SSH

# 5.3.2.1 Configure no root login
no_root_login="PermitRootLogin no"
if ! grep -q "^$no_root_login" /mnt/etc/ssh/sshd_config; then
  log "configuring sshd_config to not permit root login"
  sed -i s/"^#PermitRootLogin.*"/"$no_root_login"/ /mnt/etc/ssh/sshd_config
  changed
fi

# 5.3.2.2 Configure non-standard port
ssh_port_line="Port $ssh_port"
if ! grep -q "^$ssh_port_line" /mnt/etc/ssh/sshd_config; then
  log "configuring sshd_config to use port $ssh_port"
  sed -i s/"^#Port.*"/"$ssh_port_line"/ /mnt/etc/ssh/sshd_config
  restartnow
fi

# 5.3.2.3 Enable sshd service
if ! arch-chroot /mnt systemctl is-enabled sshd &>/dev/null; then
  log "enabling sshd"
  arch-chroot /mnt systemctl enable sshd
  changed
fi

# 5.3.3 Enable avahi-daemon
if ! arch-chroot /mnt systemctl is-enabled avahi-daemon; then
  log "enabling avahi-daemon"
  arch-chroot /mnt systemctl enable avahi-daemon
  changed
fi

# 5.3.4 Firewall

# 5.3.4.1 Bind mount live kernel modules for ufw
# might be prudent to do this always for all arch installations
live_kernel=$(uname -r)
if [[ ! -d "/mnt/lib/modules/$live_kernel" ]]; then
  log "bind mounting live kernel modules for ufw"
  mkdir -p "/mnt/lib/modules/$live_kernel"
  mount --bind "/lib/modules/$live_kernel" "/mnt/lib/modules/$live_kernel"
  restartnow
fi

# 5.3.4.2 Disable IPv6
# Disable IPv6 to avoid kernel module issues during install
# This is due to kernel difference in live env and bootable device
# Will want to remedy this at some point - perhaps moving the actual
# user setup portion of install to
if ! grep -q "^IPV6=no" /mnt/etc/default/ufw; then
  log "ufw: disabling IPv6"
  arch-chroot /mnt sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
  changed
fi

# 5.3.4.3 Default deny incoming
if ! arch-chroot /mnt ufw status verbose | grep -q "deny (incoming)"; then
  log "ufw: setting default deny incoming"
  arch-chroot /mnt ufw default deny incoming
  changed
fi

# 5.3.4.4 Default allow outgoing
if ! arch-chroot /mnt ufw status verbose | grep -q "allow (outgoing)"; then
  log "ufw: setting default allow outgoing"
  arch-chroot /mnt ufw default allow outgoing
  changed
fi

# 5.3.4.5 Allow TCP on port [SSH PORT]
if ! arch-chroot /mnt ufw status verbose | grep -q "$ssh_port/tcp.*ALLOW"; then
  log "ufw: allowing TCP on port $ssh_port"
  arch-chroot /mnt ufw allow $ssh_port/tcp
  changed
fi

# 5.3.4.6 Enable ufw service
if ! arch-chroot /mnt systemctl is-enabled ufw &>/dev/null; then
  log "ufw: enabling systemd service"
  arch-chroot /mnt systemctl enable ufw
  changed
fi

# 5.3.4.7 Enable firewall
if ! arch-chroot /mnt ufw status | grep -q "Status: active"; then
  log "ufw: enabling firewall"
  arch-chroot /mnt ufw --force enable
  restartnow
fi

# 5.3.5 Intrusion prevention

# 5.3.5.1 Create fail2ban jail.local config
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

# 5.3.5.2 Enable fail2ban service
if ! arch-chroot /mnt systemctl is-enabled fail2ban &>/dev/null; then
  log "fail2ban: enabling service"
  arch-chroot /mnt systemctl enable fail2ban
  changed
fi

# 5.4 Finalization

# 5.4.1 Ensure user home directory ownership
if arch-chroot find "/home/$system_user" ! -user "$system_user" -o ! -group "$system_user" | grep -q .; then
  log "setting user:group for /home/$system_user"
  arch-chroot /mnt chown -R "$system_user:$system_user" "/home/$system_user"
  changed
fi

# 5.4.2 Copy log files to system
if [[ ! -f "/mnt$log_file" ]] || [[ ! -f "/mnt$debug_log_file" ]]; then
  log "copying log files to target system"
  cp "$log_file" "/mnt$log_file"
  cp "$debug_log_file" "/mnt$debug_log_file"
  changed
fi

# 5.4.3 Verify changes
if [[ "$changes" -gt 0 ]]; then
  log "restarting to verify $changes changes"
  exec "$(realpath "$0")"
fi

# 5.4.4 Remove temporary passwordless sudo file
for _ in {1..3}; do
  if [[ ! -f "/mnt$temp_sudoersd_file" ]]; then
    break
  fi

  log "removing temporary passwordless sudo file"
  rm "/mnt$temp_sudoersd_file"
  sleep 1
done

if [[ -f "/mnt$temp_sudoersd_file" ]]; then
  log "WARNING: failed to remove $temp_sudoersd_file. Remove manually, then reboot the system."
  exit
fi

# 5.4.5 Reboot
log "installation completed successfully"
reboot
