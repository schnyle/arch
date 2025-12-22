#!/bin/bash

# configuration
BOOT_SIZE="512M"
SWAP_SIZE="2G"
USERNAME="kyle"

LOG_FILE="/var/log/install.log"
DEBUG_LOG_FILE="/var/log/install-debug.log"

# logging
log() { echo "$(date '+%H:%M:%S') $*" | tee -a $LOG_FILE; }
log "starting Arch installation"

# redirect ouput to verbose log file
if [[ -z "$LOGGING_SETUP" ]]; then
  exec 1> >(tee -a $DEBUG_LOG_FILE)
  exec 2>&1
  export LOGGING_SETUP=1
fi

restartnow() { log "restarting install script" && exec "$(realpath "$0")"; }

CHANGES=0
changed() { ((CHANGES++)); }

HAS_NVIDIA=$(
  lspci | grep -i nvidia
  echo $?
)

if [[ ! -f /var/lib/pacman/sync/core.db ]]; then
  log "initializing pacman"
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
HOSTNAME="arch-$(date '+%Y%m%d')"
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

# 4. Reboot
# (skip reboot - continuing with post-installation)

# 5. Post-installation

# 5.1 user setup

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

# install pulse audio and configure service
if ! arch-chroot /mnt pacman -Q pulseaudio &>/dev/null; then
  log "installing pulseaudio"
  arch-chroot /mnt pacman -S --noconfirm pulseaudio
  changed
fi

if [[ ! -d "/mnt/home/$USERNAME/.config/systemd/user/default.target.wants" ]]; then
  log "creating pulseaudio systemd directory"
  arch-chroot /mnt mkdir -p "/home/$USERNAME/.config/systemd/user/default.target.wants"
  restartnow
fi

SYMLINK="/home/$USERNAME/.config/systemd/user/default.target.wants/pulseaudio.service"
TARGET="/usr/lib/systemd/user/pulseaudio.service"
if [[ $(arch-chroot /mnt readlink "$SYMLINK" 2>/dev/null) != "$TARGET" ]]; then
  log "enabling pulseaudio user service"
  arch-chroot /mnt ln -sf "$TARGET" "$SYMLINK"
  changed
fi

if arch-chroot /mnt find "/home/$USERNAME/.config" ! -user "$USERNAME" -o ! -group "$USERNAME" | grep -q .; then
  log "setting .config/ directory ownership"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
  changed
fi

# install Arch User Repository helper (yay)
if ! arch-chroot /mnt pacman -Q base-devel &>/dev/null; then
  log "installing base-devel"
  arch-chroot /mnt pacman -S --noconfirm base-devel
  restartnow
fi

if [[ ! -d /mnt/opt/yay/.git ]]; then
  log "cloning yay"
  arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /opt/yay
  restartnow
fi

if arch-chroot /mnt find /opt/yay ! -user "$USERNAME" -o ! -group "$USERNAME" | grep -q .; then
  log "setting yay directory ownership"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" /opt/yay
  changed
fi

if ! arch-chroot /mnt which yay &>/dev/null; then
  log "building and installing yay"
  arch-chroot /mnt sudo -u "$USERNAME" makepkg -si -D /opt/yay --noconfirm
  changed
fi

# setup custom dotfiles
if ! arch-chroot /mnt pacman -Q stow &>/dev/null; then
  log "installing stow"
  arch-chroot /mnt pacman -S --noconfirm stow
  restartnow
fi

if ! arch-chroot /mnt test -d "/home/$USERNAME/.dotfiles"; then
  log "cloning dotfiles repository"
  arch-chroot /mnt sudo -u "$USERNAME" git clone https://github.com/schnyle/dotfiles.git "/home/$USERNAME/.dotfiles"
  arch-chroot /mnt sudo -u "$USERNAME" bash "/home/$USERNAME/.dotfiles/install.sh"
fi

# 5.2 install software

# enable 32 bit libraries
if ! (grep -q "^\[multilib\]" /mnt/etc/pacman.conf && grep -q "^Include = /etc/pacman.d/mirrorlist" /mnt/etc/pacman.conf); then
  log "enabling 32-bit libraries"
  sed -i '/^#\[multilib\]/,/^#Include/ {s/^#//; }' /mnt/etc/pacman.conf
  arch-chroot /mnt pacman -Sy
  restartnow
fi

packages=(
  adobe-source-code-pro-fonts # Monospaced font family for user interface and coding environments
  alacritty                   # a cross-platform, GPU-accelerated terminal emulator
  alsa-utils                  # Advanced Linux Sound Architecture - Utilities
  arandr                      # provide a simple visual front end for XRandR 1.2
  cmake                       # a cross-platform open-source make system
  i3-wm                       # improved dynamic tiling window manager
  i3blocks                    # define blocks for your i3bar status line
  i3lock                      # improved screenlocker based upon XCB and PAM
  i3status                    # generates status bar to use with i3bar, dzen2 or xmobar
  inetutils                   # a collection of common network programs
  less                        # a terminal based program for viewing text files
  man-db                      # a utility for reading man pages
  networkmanager              # network connection manager and user application
  pavucontrol                 # PulseAudio volume control
  qmk                         # CLI tool for customzing supported mechanical keyboards
  qutebrowser                 # a keyboard-driven, vim-like browser base on Python and Qt
  reflector                   # a Python 3 module and script to retrieve and filter the latest Pacman mirror list
  stow                        # manage installation of multiple softwares in the same directory tree/
  tmux                        # terminal multiplexer
  vim                         # Vi Improved, a highly configurable, improved version of the vi text editor
  xorg-server                 # Xorg X server
  xorg-xinit                  # X.Org initialisation program
  openssh                     # SSH protocol implementation for remote login, command execution and file transfer
  xclip                       # command line interface to the X11 clipboard
)

for pkg in "${packages[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
    log "installing $pkg"
    arch-chroot /mnt pacman -S --noconfirm "$pkg"
    changed
  fi
done

# enable NetworkManager service
if ! arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null; then
  log "enabling NetworkManager service"
  arch-chroot /mnt systemctl enable NetworkManager
  changed
fi

# minesweeper
if ! arch-chroot /mnt test -x /opt/minesweeper/minesweeper; then
  log "installing minesweeper"
  arch-chroot /mnt mkdir -p /opt/minesweeper
  curl -fL https://github.com/schnyle/minesweeper/releases/latest/download/minesweeper -o /mnt/opt/minesweeper/minesweeper
  arch-chroot /mnt chmod +x /opt/minesweeper/minesweeper
  restartnow
fi

if [[ $(arch-chroot /mnt readlink /usr/local/bin/minesweeper 2>/dev/null) != /opt/minesweeper/minesweeper ]]; then
  log "create symlink for minesweeper"
  arch-chroot /mnt ln -sf /opt/minesweeper/minesweeper /usr/local/bin/minesweeper
  changed
fi

# steam
if [[ $HAS_NVIDIA -eq 0 ]] && ! arch-chroot /mnt pacman -Q steam lib32-nvidia-utils &>/dev/null; then
  log "installing steam & 32 bit NVIDIA utils"
  arch-chroot /mnt pacman -S --noconfirm steam lib32-nvidia-utils
  changed
fi

# VS Code
if ! arch-chroot /mnt pacman -Q visual-studio-code-bin &>/dev/null; then
  log "installing VS Code"
  arch-chroot /mnt sudo -u "$USERNAME" yay -S --noconfirm visual-studio-code-bin
  restartnow
fi

extensions=(
  ms-vscode.cmake-tools
  ms-vscode.cpptools
  vscode-icons-team.vscode-icons
  tomoki1207.pdf
  mechatroner.rainbow-csv
)

for ext in "${extensions[@]}"; do
  if ! arch-chroot /mnt sudo -u "$USERNAME" code --list-extensions | grep -q "^$ext$"; then
    arch-chroot /mnt sudo -u "$USERNAME" code --install-extension "$ext"
    changed
  fi
done

# NVIDIA drivers
if [[ $HAS_NVIDIA -eq 0 ]] && ! arch-chroot /mnt pacman -Q nvidia-dkms nvidia-utils nvidia-settings &>/dev/null; then
  log "installing nvidia drivers (DKMS)"
  arch-chroot /mnt pacman -S --noconfirm nvidia-dkms nvidia-utils nvidia-settings
  changed
fi

# compositor (bare-metal only)
if ! arch-chroot /mnt systemd-detect-virt -q && ! arch-chroot /mnt pacman -Q picom &>/dev/null; then
  log "installing compositor"
  arch-chroot /mnt pacman -S --noconfirm picom
  changed
fi

# symlinks
if [[ $(arch-chroot /mnt readlink /usr/local/bin/audio 2>/dev/null) != /usr/bin/pavucontrol ]]; then
  log "creating symlink for pavucontrol"
  arch-chroot /mnt ln -sf /usr/bin/pavucontrol /usr/local/bin/audio
  changed
fi

if [[ $(arch-chroot /mnt readlink /usr/local/bin/displays 2>/dev/null) != /usr/bin/arandr ]]; then
  log "creating symlink for arandr"
  arch-chroot /mnt ln -sf /usr/bin/arandr /usr/local/bin/displays
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
