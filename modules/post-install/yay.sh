: "${system_user:=}"

yay_pacman_packages=(
  base-devel
  git
)
add_pacman_packages "${yay_pacman_packages[@]}"

configure_yay() {
  require_var system_user

  local changed=0

  if [[ ! -d /mnt/opt/yay/.git ]]; then
    log "cloning yay"
    arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /opt/yay
    changed=1
  fi

  if arch-chroot /mnt find /opt/yay ! -user "$system_user" -o ! -group "$system_user" | grep -q .; then
    log "setting yay directory ownership"
    arch-chroot /mnt chown -R "$system_user:$system_user" /opt/yay
    changed=1
  fi

  if ! arch-chroot /mnt pacman -Q yay &>/dev/null; then
    log "building and installing yay"
    arch-chroot /mnt sudo -u "$system_user" makepkg -si -D /opt/yay --noconfirm
    changed=1
  fi

  return $changed
}
