: "${system_user:=}"

virtualization_pacman_packages=(
  qemu-full
  virt-manager
  virt-viewer
  dnsmasq
  vde2
  openbsd-netcat
  dmidecode
  libguestfs
  edk2-ovmf
)
add_pacman_packages "${virtualization_pacman_packages[@]}"

configure_virtualization() {
  require_var system_user

  local changed=0

  if ! arch-chroot /mnt systemctl is-enabled libvirtd.socket &>/dev/null; then
    log "enabling libvirtd.socket"
    arch-chroot /mnt systemctl enable libvirtd.socket
    changed=1
  fi

  if ! arch-chroot /mnt groups "$system_user" | grep -q libvirt; then
    log "adding user to libvirt group"
    arch-chroot /mnt usermod -aG libvirt "$system_user"
    changed=1
  fi

  return $changed
}
