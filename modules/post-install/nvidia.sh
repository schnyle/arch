nvidia_pacman_packages=(
  linux-headers
  nvidia-dkms
  nvidia-utils
  nvidia-settings
)
add_pacman_packages "${nvidia_pacman_packages[@]}"

configure_nvidia() {
  return 0
}
