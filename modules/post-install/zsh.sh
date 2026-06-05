: "${system_user:=}"

zsh_pacman_packages=(
  zsh
)
add_pacman_packages "${zsh_pacman_packages[@]}"

configure_zsh() {
  require_var system_user

  grep "^$system_user:" /mnt/etc/passwd | grep -q "/usr/bin/zsh" && return 0

  log "setting zsh as default shell for $system_user"
  arch-chroot /mnt chsh -s /usr/bin/zsh "$system_user"
  return 1
}
