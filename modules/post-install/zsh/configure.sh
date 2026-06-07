# zsh is installed and set as default shell.

: "${system_user:=}"

configure() {
  grep "^$system_user:" /mnt/etc/passwd | grep -q "/usr/bin/zsh" && return 0

  log "setting zsh as default shell for $system_user"
  arch-chroot /mnt chsh -s /usr/bin/zsh "$system_user"
  return 1
}
