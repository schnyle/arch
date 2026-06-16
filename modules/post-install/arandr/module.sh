pacman_packages=(
  arandr
)

# arandr is installed and has a 'displays' symlink in /usr/local/bin.

configure() {
  ensure_symlink "/usr/bin/arandr" "/usr/local/bin/displays"
}
