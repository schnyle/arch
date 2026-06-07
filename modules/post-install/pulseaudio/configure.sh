# pulseaudio is installed and enabled.

: "${system_user:=}"

configure() {
  local target="/usr/lib/systemd/user/pulseaudio.service"
  local link="/mnt/home/$system_user/.config/systemd/user/default.target.wants/pulseaudio.service"
  ensure_symlink "$target" "$link"
}
