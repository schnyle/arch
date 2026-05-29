pacman_packages=()

add_pacman_packages() {
  local package
  local new_packages=()
  for package in "$@"; do
    if ! package_exists "$package"; then
      pacman_packages+=("$package")
      new_packages+=("$package")
    fi
  done
  [[ ${#new_packages[@]} -gt 0 ]] && log "registered ${#new_packages[@]} pacman packages: ${new_packages[*]}"
}

package_exists() {
  local package
  local new_package="$1"
  for package in "${pacman_packages[@]}"; do
    if [[ "$package" == "$new_package" ]]; then
      return 0
    fi
  done
  return 1
}

install_all_pacman_packages() {
  log "installing ${#pacman_packages[@]} pacman packages"
  arch-chroot /mnt pacman -S --noconfirm --needed "${pacman_packages[@]}"
}
