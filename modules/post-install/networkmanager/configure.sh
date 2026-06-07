# networkmanager is installed and enabled.

configure() {
  ensure_service_enabled NetworkManager
}
