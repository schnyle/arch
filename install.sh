#!/bin/bash

# configuration
USERNAME="kyle"
EMAIL="kylesch115@gmail.com"

BOOT_SIZE="512M"
SWAP_SIZE="2G"

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

HAS_NVIDIA=$(
  lspci | grep -iq "nvidia"
  echo $?
)

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

    # remove any EFI boot entries pointing to this device
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
,$BOOT_SIZE,U
,$SWAP_SIZE,S
,,L
write
EOF

  if [[ $install_device =~ nvme ]]; then
    install_device="${install_device}p"
  fi

  log "formatting the partitions"
  # 1.10 Format the partitions
  mkfs.fat -F32 "${install_device}1"
  mkswap "${install_device}2"
  swapon "${install_device}2"
  mkfs.ext4 "${install_device}3"

  log "mounting the file systems"
  # 1.11 Mount the file systems
  mount "${install_device}3" /mnt
  mount --mkdir "${install_device}1" /mnt/boot
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
if ! grep -q "^UUID=" /mnt/etc/fstab; then
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
grub_bootloader_exists=$(
  efibootmgr -v | grep -q "grubx64.efi"
  echo $?
)

if ! arch-chroot /mnt pacman -Q grub efibootmgr os-prober &>/dev/null; then
  log "installing bootloader packages"
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr os-prober
  restartnow
fi

if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  log "installing GRUB bootloader"
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  changed
fi

if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
  log "configuring GRUB bootloader"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  changed
fi

if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
  log "creating fallback bootloader for picky UEFI implementations"
  arch-chroot /mnt mkdir -p /boot/EFI/BOOT
  arch-chroot /mnt cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
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

# create ed25519 key
priv_key_path="/home/$USERNAME/.ssh/id_ed25519"
pub_key_path="/home/$USERNAME/.ssh/id_ed25519.pub"

if ! arch-chroot /mnt pacman -Q openssh &>/dev/null; then
  log "installing openssh"
  arch-chroot /mnt pacman -S --noconfirm openssh
  restartnow
fi

if ! [[ -f "/mnt/$priv_key_path" ]]; then
  log "creating ed25519 key for $USERNAME"
  arch-chroot /mnt sudo -u $USERNAME ssh-keygen -t ed25519 -C $EMAIL -f $priv_key_path -N ""
  restartnow
fi

if [[ $(arch-chroot /mnt stat -c "%a" "/home/$USERNAME/.ssh") != "700" ]]; then
  log "setting permissions for /home/$USERNAME/.ssh/"
  arch-chroot /mnt chmod 700 "/home/$USERNAME/.ssh"
  changed
fi

if [[ $(arch-chroot /mnt stat -c "%a" $priv_key_path) != "600" ]]; then
  log "setting permissions for $priv_key_path"
  arch-chroot /mnt chmod 600 $priv_key_path
  changed
fi

if [[ $(arch-chroot /mnt stat -c "%a" $pub_key_path) != "644" ]]; then
  log "setting permissions for $pub_key_path"
  arch-chroot /mnt chmod 644 $pub_key_path
  changed
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
  pavucontrol                 # PulseAudio volume control
  qmk                         # CLI tool for customzing supported mechanical keyboards
  qutebrowser                 # a keyboard-driven, vim-like browser base on Python and Qt
  reflector                   # a Python 3 module and script to retrieve and filter the latest Pacman mirror list
  sof-firmware                # sound open firmware
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

# configure dark theme for GTK applications
read -r -d '' GTK_SETTINGS <<"EOF"
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=true
EOF

GTK3_CONFIG="/mnt/home/$USERNAME/.config/gtk-3.0/settings.ini"
if [[ "$(cat "$GTK3_CONFIG" 2>/dev/null)" != "$GTK_SETTINGS" ]]; then
  log "configuring GTK 3.0 dark mode"
  mkdir -p "/mnt/home/$USERNAME/.config/gtk-3.0"
  echo "$GTK_SETTINGS" >"$GTK3_CONFIG"
  changed
fi

GTK4_CONFIG="/mnt/home/$USERNAME/.config/gtk-4.0/settings.ini"
if [[ "$(cat "$GTK4_CONFIG" 2>/dev/null)" != "$GTK_SETTINGS" ]]; then
  log "configuring GTK 4.0 dark mode"
  mkdir -p "/mnt/home/$USERNAME/.config/gtk-4.0"
  echo "$GTK_SETTINGS" >"$GTK4_CONFIG"
  changed
fi

# enable NetworkManager service
if ! arch-chroot /mnt systemctl is-enabled NetworkManager &>/dev/null; then
  log "enabling NetworkManager service"
  arch-chroot /mnt systemctl enable NetworkManager
  changed
fi

# NVIDIA drivers
if [[ $HAS_NVIDIA -eq 0 ]] && ! arch-chroot /mnt pacman -Q linux-headers &>/dev/null; then
  log "installing linux headers"
  arch-chroot /mnt pacman -S --noconfirm linux-headers
  restartnow
fi

if [[ $HAS_NVIDIA -eq 0 ]] && ! arch-chroot /mnt pacman -Q nvidia-dkms nvidia-utils nvidia-settings &>/dev/null; then
  log "installing nvidia drivers (DKMS)"
  arch-chroot /mnt pacman -S --noconfirm nvidia-dkms nvidia-utils nvidia-settings
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

# compositor (bare-metal only)
if ! arch-chroot /mnt systemd-detect-virt -q && ! arch-chroot /mnt pacman -Q picom &>/dev/null; then
  log "installing compositor"
  arch-chroot /mnt pacman -S --noconfirm picom
  changed
fi

# virtual machine
vm_packages=(
  qemu-full
  virt-manager
  virt-viewer
  dnsmasq
  vde2
  bridge-utils
  openbsd-netcat
  dmidecode
  libguestfs
  edk2-ovmf
)

for pkg in "${vm_packages[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" &>/dev/null; then
    log "installing $pkg"
    arch-chroot /mnt pacman -S --noconfirm "$pkg"
    changed
  fi
done

if ! arch-chroot /mnt systemctl is-enabled libvirtd.socket &>/dev/null; then
  log "enabling libvirtd.socket"
  arch-chroot /mnt systemctl enable libvirtd.socket
  changed
fi

if ! arch-chroot /mnt groups "$USERNAME" | grep -q libvirt; then
  log "adding user to libvirt group"
  arch-chroot /mnt usermod -aG libvirt "$USERNAME"
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

# ensure home directory ownership
if find "/mnt/home/$USERNAME" \( ! -user "$USERNAME" -o ! -group "$USERNAME" \) -print -quit 2>/dev/null | grep -q .; then
  log "setting user:group for /home/$USERNAME"
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
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
