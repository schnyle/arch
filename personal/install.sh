#!/bin/bash

# ========
# 0. Setup
# ========

# 0.1 Installation configuration
# --------------------------

# 0.1.1 User
system_user="kyle"
git_name="kyle"
email="kylesch115@gmail.com"

# 0.1.2 System
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="arch-$(date '+%Y%m%d')"
temp_sudoersd_file="/etc/sudoers.d/temp_install"
boot_part_size="512M"
swap_size="2G"

# 0.1.3 Script
log_file="/var/log/install.log"
debug_log_file="/var/log/install-debug.log"

# 0.2 Software lists
# ------------------

# 0.2.1 Core packages
# Always installed
core_packages=(
  adobe-source-code-pro-fonts # Monospaced font family for user interface and coding environments
  alacritty                   # a cross-platform, GPU-accelerated terminal emulator
  alsa-utils                  # Advanced Linux Sound Architecture - Utilities
  arandr                      # provide a simple visual front end for XRandR 1.2
  base-devel                  # Basic tools to build Arch Linux packages
  bitwarden                   # a secure and free password manager for all of your devices
  cmake                       # a cross-platform open-source make system
  gnome-themes-extra          # extra GNOME themes (legacy HighContrast icon theme and index files for Adwaita)
  i3-wm                       # improved dynamic tiling window manager
  i3blocks                    # define blocks for your i3bar status line
  i3lock                      # improved screenlocker based upon XCB and PAM
  i3status                    # generates status bar to use with i3bar, dzen2 or xmobar
  inetutils                   # a collection of common network programs
  less                        # a terminal based program for viewing text files
  man-db                      # a utility for reading man pages
  neovim                      # fork of Vim aiming to improve user experience, plugins, and GUIs
  networkmanager              # network connection manager and user application
  npm                         # JavaScript package manager
  openssh                     # SSH protocol implementation for remote login, command execution and file transfer
  pavucontrol                 # PulseAudio volume control
  pulseaudio                  # a featureful, general-purpose sound server
  qmk                         # CLI tool for customzing supported mechanical keyboards
  qutebrowser                 # a keyboard-driven, vim-like browser base on Python and Qt
  reflector                   # a Python 3 module and script to retrieve and filter the latest Pacman mirror list
  sof-firmware                # sound open firmware
  stow                        # manage installation of multiple softwares in the same directory tree/
  tmux                        # terminal multiplexer
  tree                        # a directory listing program displaying a depth indented list of files
  vi                          # the original ex/vi text editor
  vim                         # Vi Improved, a highly configurable, improved version of the vi text editor
  xorg-server                 # Xorg X server
  xorg-xinit                  # X.Org initialisation program
  unzip                       # for extracting and viewing files in .zip archives
  wget                        # network utility to retrieve files from the web
  xclip                       # command line interface to the X11 clipboard
  zsh                         # a very advanced and programmable command interpreter (shell) for UNIX
)

# 0.2.2 NVIDIA packages
# Only installed if NVIDIA PCI devices are found
nvidia_packages=(
  linux-headers   # headers and scripts for building modules for the Linux kernel
  nvidia-dkms     # NVIDIA open kernel modules - module sources
  nvidia-utils    # NVIDIA driver utilities
  nvidia-settings # tool for configuring the NVIDIA graphics driver
)

# 0.2.3 Virtual machine packages
# Only installed if the system is not a virtual machine
vm_packages=(
  qemu-full      # a full QEMU setup
  virt-manager   # desktop user interface for managing virtual machines
  virt-viewer    # a lightweight interface for interacting with the graphical display of a virtualized guest OS
  dnsmasq        # lightweight, easy to configure DNS forwarder and DHCP server
  vde2           # Virtual Distributed Ethernet for emulators like qemu
  bridge-utils   # utilities for configuring the Linux ethernet bridge
  openbsd-netcat # TCP/IP swiss army knife. OpenDSG variant
  dmidecode      # Desktop Management Interface table related utilities
  libguestfs     # access and modify virtual machine disk images
  edk2-ovmf      # firmware for virtual machines (x86_64, i686)
)

# 0.2.4 VS Code extensions
vscode_extensions=(
  ms-vscode.cmake-tools
  ms-vscode.cpptools
  vscode-icons-team.vscode-icons
  tomoki1207.pdf
  mechatroner.rainbow-csv
  amazonwebservices.amazon-q-vscode
  vscodevim.vim
)

# 0.3 Runtime constants
# ---------------------

is_vm=$(
  systemd-detect-virt -q
  echo $?
)

has_nvidia=$(
  lspci | grep -iq "nvidia"
  echo $?
)

main_system_uuid="0218a900-edb8-11ee-9a60-aaa17ee25e02"

# 0.4 Function definitions
# ------------------------

# 0.4.1 Logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a $log_file; }

# 0.4.2 Redirect stdout to log file
if [[ -z "$LOGGING_SETUP" ]]; then
  log "starting Arch installation"
  exec 1> >(tee -a $debug_log_file)
  exec 2>&1
  export LOGGING_SETUP=1
fi

# 0.4.3 Immediate script restart
restartnow() { log "restarting install script" && exec "$(realpath "$0")"; }

# 0.4.4 Track changes made
changes=0
changed() { ((changes++)); }

# 0.5 Initialize pacman
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
# ----------------------

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
  sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /mnt/etc/sudoers
  changed
fi

# 5.1.1.4 Setup temporary passwordless sudo for user
# Create a temporary file which allows the user to run sudo commands without password prompt.
# Removed at the end of the installation.
if ! grep -q "$system_user ALL=(ALL) NOPASSWD: ALL" "/mnt$temp_sudoersd_file" &>/dev/null || [[ $(stat -c "%a" "/mnt$temp_sudoersd_file") != "440" ]]; then
  log "configuring temporary passwordless sudo for $system_user"
  bash -c "echo '$system_user ALL=(ALL) NOPASSWD: ALL' >/mnt$temp_sudoersd_file"
  chmod 440 "/mnt$temp_sudoersd_file"
  restartnow
fi

# 5.1.2 Enable 32-bit libraries

if ! (grep -q "^\[multilib\]" /mnt/etc/pacman.conf && grep -q "^Include = /etc/pacman.d/mirrorlist" /mnt/etc/pacman.conf); then
  log "enabling 32-bit libraries"
  sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /mnt/etc/pacman.conf
  arch-chroot /mnt pacman -Sy
  restartnow
fi

# 5.2 Software installation
# ------------------------

# 5.2.1 Core pacman packages

for pkg in "${core_packages[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
    log "installing core pacman package $pkg"
    arch-chroot /mnt pacman -S --noconfirm "$pkg"
    changed
  fi
done

# 5.2.2 Arch User Repository helper (yay)

# 5.2.2.1 Clone repository
if [[ ! -d /mnt/opt/yay/.git ]]; then
  log "cloning yay"
  arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /opt/yay
  restartnow
fi

# 5.2.2.2 Set user ownership
if arch-chroot /mnt find /opt/yay ! -user "$system_user" -o ! -group "$system_user" | grep -q .; then
  log "setting yay directory ownership"
  arch-chroot /mnt chown -R "$system_user:$system_user" /opt/yay
  changed
fi

# 5.2.2.3 Build and install
if ! arch-chroot /mnt which yay &>/dev/null; then
  log "building and installing yay"
  arch-chroot /mnt sudo -u "$system_user" makepkg -si -D /opt/yay --noconfirm
  changed
fi

# 5.2.3 AUR packages

# 5.2.3.1 VS Code
if ! arch-chroot /mnt pacman -Q visual-studio-code-bin &>/dev/null; then
  log "installing VS Code"
  arch-chroot /mnt sudo -u "$system_user" yay -S --noconfirm visual-studio-code-bin
  restartnow
fi

# 5.2.3.2 VS Code extensions
for ext in "${vscode_extensions[@]}"; do
  if ! arch-chroot /mnt sudo -u "$system_user" code --list-extensions | grep -q "^$ext$"; then
    arch-chroot /mnt sudo -u "$system_user" code --install-extension "$ext"
    changed
  fi
done

# 5.2.4 NVIDIA packages
if [[ $has_nvidia -eq 0 ]]; then
  for pkg in "${nvidia_packages[@]}"; do
    if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
      log "installing NVIDIA package $pkg"
      arch-chroot /mnt pacman -S --noconfirm "$pkg"
      changed
    fi
  done
fi

# 5.2.5 Virtual machine packages
if [[ $is_vm -eq 1 ]]; then
  for pkg in "${vm_packages[@]}"; do
    if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
      log "installing VM package $pkg"
      arch-chroot /mnt pacman -S --noconfirm "$pkg"
      changed
    fi
  done
fi

# 5.2.6 oh-my-zsh
if [[ ! -d "/mnt/home/$system_user/.oh-my-zsh" ]]; then
  log "installing oh-my-zsh"
  arch-chroot /mnt sudo -u "$system_user" bash -c "curl -L https://install.ohmyz.sh | sh"
  changed
fi

# 5.2.7 Minesweeper
if [[ ! -x /mnt/opt/minesweeper/minesweeper ]]; then
  log "installing minesweeper"
  mkdir -p /mnt/opt/minesweeper
  curl -fL https://github.com/schnyle/minesweeper/releases/latest/download/minesweeper -o /mnt/opt/minesweeper/minesweeper
  chmod +x /mnt/opt/minesweeper/minesweeper
  restartnow
fi

# 5.2.8 Steam
if [[ $has_nvidia -eq 0 ]] && ! arch-chroot /mnt pacman -Q steam lib32-nvidia-utils &>/dev/null; then
  log "installing steam & 32 bit NVIDIA utils"
  arch-chroot /mnt pacman -S --noconfirm steam lib32-nvidia-utils
  changed
fi

# 5.2.9 Compositor
# only for bare-metal installations
if [[ $is_vm -eq 1 ]] && ! arch-chroot /mnt pacman -Q picom &>/dev/null; then
  log "installing compositor"
  arch-chroot /mnt pacman -S --noconfirm picom
  changed
fi

# 5.3 Configuration
# ----------------------

# 5.3.1 git user.email and user.name

if [[ $(arch-chroot /mnt sudo -u "$system_user" git config --global user.email) != "$email" ]]; then
  log "configuring $email as git config user.email"
  arch-chroot /mnt sudo -u "$system_user" git config --global user.email "$email"
  changed
fi

if [[ $(arch-chroot /mnt sudo -u "$system_user" git config --global user.name) != "$git_name" ]]; then
  log "configuring $git_name as git config user.name"
  arch-chroot /mnt sudo -u "$system_user" git config --global user.name "$git_name"
  changed
fi

# 5.3.2 Configure user default shell to zsh
if ! grep "^$system_user:" /mnt/etc/passwd | grep -q "/usr/bin/zsh"; then
  log "setting zsh as default shell for $system_user"
  arch-chroot /mnt chsh -s /usr/bin/zsh "$system_user"
  changed
fi

# 5.3.3 Pulse audio

# 5.3.3.1 Create systemd directory
if [[ ! -d "/mnt/home/$system_user/.config/systemd/user/default.target.wants" ]]; then
  log "creating pulseaudio systemd directory"
  mkdir -p "/mnt/home/$system_user/.config/systemd/user/default.target.wants"
  restartnow
fi

# 5.3.3.2 Enable user service
symlink="/mnt/home/$system_user/.config/systemd/user/default.target.wants/pulseaudio.service"
target="/usr/lib/systemd/user/pulseaudio.service" # path as it will exist in the booted system (no /mnt prefix)
if [[ $(readlink "$symlink" 2>/dev/null) != "$target" ]]; then
  log "enabling pulseaudio user service"
  ln -sf "$target" "$symlink"
  changed
fi

# 5.3.4 Custom dotfiles
if [[ ! -d "/mnt/home/$system_user/.dotfiles" ]]; then
  log "cloning dotfiles repository"
  arch-chroot /mnt sudo -u "$system_user" git clone https://github.com/schnyle/dotfiles.git "/home/$system_user/.dotfiles"
  arch-chroot /mnt sudo -u "$system_user" bash "/home/$system_user/.dotfiles/install.sh"
fi

# 5.3.5 ed25519 key
priv_key_path="/home/$system_user/.ssh/id_ed25519"
pub_key_path="/home/$system_user/.ssh/id_ed25519.pub"

# 5.3.5.1 Generate key
if ! [[ -f "/mnt/$priv_key_path" ]]; then
  log "creating ed25519 key for $system_user"
  arch-chroot /mnt sudo -u $system_user ssh-keygen -t ed25519 -C "$email" -f "$priv_key_path" -N ""
  restartnow
fi

# 5.3.5.2 Set permissions

# .ssh directory
if [[ $(stat -c "%a" "/mnt/home/$system_user/.ssh") != "700" ]]; then
  log "setting permissions for /home/$system_user/.ssh/"
  chmod 700 "/mnt/home/$system_user/.ssh"
  changed
fi

# private key
if [[ $(stat -c "%a" "/mnt/$priv_key_path") != "600" ]]; then
  log "setting permissions for $priv_key_path"
  chmod 600 "/mnt/$priv_key_path"
  changed
fi

# public key
if [[ $(stat -c "%a" "/mnt/$pub_key_path") != "644" ]]; then
  log "setting permissions for $pub_key_path"
  chmod 644 "/mnt/$pub_key_path"
  changed
fi

# 5.3.6 Setup displays
# Only for main system (uses hardware UUID)
current_system_uuid=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null)
if [[ $is_vm -eq 1 ]] && [[ -n $current_system_uuid ]] && [[ "$current_system_uuid" == "$main_system_uuid" ]] && ! [[ -f "/mnt/home/$system_user/.screenlayout/display.sh" ]]; then
  log "configuring displays"
  mkdir -p "/mnt/home/$system_user/.screenlayout"
  cat >"/mnt/home/$system_user/.screenlayout/display.sh" <<"EOF"
#!/bin/sh
xrandr --output HDMI-0 --mode 1920x1080 --pos 4480x354 --rotate normal --output DP-0 --off --output DP-1 --off --output DP-2 --mode 1920x1080 --pos 0x354 --rotate normal --output DP-3 --off --output DP-4 --primary --mode 2560x1440 --pos 1920x0 --rotate normal --output DP-5 --off
EOF
  restartnow
fi

if [[ $is_vm -eq 1 ]] && [[ -n $current_system_uuid ]] && [[ "$current_system_uuid" == "$main_system_uuid" ]] && [[ $(stat -c "%a" "/mnt/home/$system_user/.screenlayout/display.sh") != "700" ]]; then
  log "setting permissions for screen layout config file"
  chmod 700 "/mnt/home/$system_user/.screenlayout/display.sh"
  changed
fi

# 5.3.7 Configure dark theme for GTK applications
read -r -d '' gtk_settings <<"EOF"
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=true
EOF

# GTK 3.0
GTK3_CONFIG="/mnt/home/$system_user/.config/gtk-3.0/settings.ini"
if [[ "$(cat "$GTK3_CONFIG" 2>/dev/null)" != "$gtk_settings" ]]; then
  log "configuring GTK 3.0 dark mode"
  mkdir -p "/mnt/home/$system_user/.config/gtk-3.0"
  echo "$gtk_settings" >"$GTK3_CONFIG"
  changed
fi

# GTK 4.0
GTK4_CONFIG="/mnt/home/$system_user/.config/gtk-4.0/settings.ini"
if [[ "$(cat "$GTK4_CONFIG" 2>/dev/null)" != "$gtk_settings" ]]; then
  log "configuring GTK 4.0 dark mode"
  mkdir -p "/mnt/home/$system_user/.config/gtk-4.0"
  echo "$gtk_settings" >"$GTK4_CONFIG"
  changed
fi

# 5.3.8 Enable NetworkManager service
if ! arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null; then
  log "enabling NetworkManager service"
  arch-chroot /mnt systemctl enable NetworkManager
  changed
fi

# 5.3.9 Virtual machine

# 5.3.9.1 Enable libvirtd.socket
if [[ $is_vm -eq 1 ]] && ! arch-chroot /mnt systemctl is-enabled libvirtd.socket &>/dev/null; then
  log "enabling libvirtd.socket"
  arch-chroot /mnt systemctl enable libvirtd.socket
  changed
fi

# 5.3.9.2 Add user to libvirt group
if [[ $is_vm -eq 1 ]] && ! arch-chroot /mnt groups "$system_user" | grep -q libvirt; then
  log "adding user to libvirt group"
  arch-chroot /mnt usermod -aG libvirt "$system_user"
  changed
fi

# 5.3.10 symlinks

# 5.3.10.1 Minesweeper
if [[ $(readlink /mnt/usr/local/bin/minesweeper 2>/dev/null) != /opt/minesweeper/minesweeper ]]; then
  log "create symlink for minesweeper"
  ln -sf /opt/minesweeper/minesweeper /mnt/usr/local/bin/minesweeper
  changed
fi

# 5.3.10.2 pavucontrol
if [[ $(readlink /mnt/usr/local/bin/audio 2>/dev/null) != /usr/bin/pavucontrol ]]; then
  log "creating symlink for pavucontrol"
  ln -sf /usr/bin/pavucontrol /mnt/usr/local/bin/audio
  changed
fi

# 5.3.10.3 arandr
if [[ $(readlink /mnt/usr/local/bin/displays 2>/dev/null) != /usr/bin/arandr ]]; then
  log "creating symlink for arandr"
  ln -sf /usr/bin/arandr /mnt/usr/local/bin/displays
  changed
fi

# 5.4 Finalization

# 5.4.1 Ensure user home directory ownership
if arch-chroot /mnt find "/home/$system_user" ! -user "$system_user" -o ! -group "$system_user" | grep -q .; then
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
