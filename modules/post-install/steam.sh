steam_pacman_packages=(
  steam
  lib32-nvidia-utils
)
add_pacman_packages "${steam_pacman_packages[@]}"

configure_steam() {
  return 0
}
