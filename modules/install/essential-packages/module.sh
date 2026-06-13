essential_packages=(
  base
  linux
  linux-firmware
  sudo
)

configure() {
  arch-chroot /mnt pacman -Q "${essential_packages[@]}" &>/dev/null && return 0

  log "installing essential packages"
  pacstrap /mnt "${essential_packages[@]}"
  return 1
}
