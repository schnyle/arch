: "${system_user:=}"
: "${git_name:=}"
: "${email:=}"

git_pacman_packages=(
  git
)
add_pacman_packages "${git_pacman_packages[@]}"

configure_git() {
  require_var system_user email git_name

  local changed=0

  if [[ $(arch-chroot /mnt sudo -u "$system_user" git config --global user.email) != "$email" ]]; then
    log "configuring $email as git config user.email"
    arch-chroot /mnt sudo -u "$system_user" git config --global user.email "$email"
    changed=1
  fi

  if [[ $(arch-chroot /mnt sudo -u "$system_user" git config --global user.name) != "$git_name" ]]; then
    log "configuring $git_name as git config user.name"
    arch-chroot /mnt sudo -u "$system_user" git config --global user.name "$git_name"
    changed=1
  fi

  return $changed
}
