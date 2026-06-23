pacman_packages=(avahi)

configure() {
  ensure_service_enabled avahi-daemon
}
