pacman_packages=(
  pavucontrol
)

# pavucontrol is installed and has symlink.

configure() {
  ensure_symlink /usr/bin/pavucontrol /usr/local/bin/audio
}
