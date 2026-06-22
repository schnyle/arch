pacman_packages=(
  base-devel
  git
)

# yay (AUR helper) is cloned, built, and installed

: "${system_user:=}"

configure() {
  local changed=0

  if [[ ! -d /opt/yay/.git ]]; then
    log "cloning yay"
    git clone https://aur.archlinux.org/yay.git /opt/yay
    changed=1
  fi

  if find /opt/yay ! -user "$system_user" -o ! -group "$system_user" | grep -q .; then
    log "setting yay directory ownership"
    chown -R "$system_user:$system_user" /opt/yay
    changed=1
  fi

  if ! pacman -Q yay &>/dev/null; then
    log "building and installing yay"
    sudo -u "$system_user" makepkg -si -D /opt/yay --noconfirm
    changed=1
  fi

  return $changed
}
