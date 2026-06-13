bootloader_remove_orphaned_entries() {
  local boot_num uuid boot_device

  while read -r boot_entry; do
    boot_num=$(echo "$boot_entry" | grep -oP "^Boot\K[0-9]{4}")

    uuid=$(echo "$boot_entry" | grep -oP "[a-f0-9-]{36}")
    [[ -z "$uuid" ]] && continue

    boot_device=$(blkid | grep -i "$uuid" | cut -d: -f1)
    if [[ -z "$boot_device" ]]; then
      log "removing orphaned boot entry $boot_num"
      efibootmgr -b "$boot_num" -B
    fi
  done < <(efibootmgr -v | grep -E "^Boot[0-9]{4}")
}

configure() {
  local changed=0
  local grub_bootloader_exists

  if ! arch-chroot /mnt pacman -Q grub efibootmgr os-prober &>/dev/null; then
    log "installing bootloader packages"
    arch-chroot /mnt pacman -S --noconfirm grub efibootmgr os-prober
    changed=1
  fi

  bootloader_remove_orphaned_entries

  efibootmgr -v | grep -q "grubx64.efi"
  grub_bootloader_exists=$?

  if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
    log "installing GRUB bootloader"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    changed=1
  fi

  if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
    log "configuring GRUB bootloader"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    changed=1
  fi

  # Create fallback bootloader for non-compliant UEFI implementations.
  # Some motherboards/UEFI firmware ignore custom boot entries and only look for the default
  # bootloader path /EFI/BOOT/BOOTX64.EFI. This creates a fallback copy of GRUB at that location
  # to ensure the system can boot even on such hardware.
  if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
    log "creating fallback bootloader for picky UEFI implementations"
    mkdir -p /mnt/boot/EFI/BOOT
    cp /mnt/boot/EFI/GRUB/grubx64.efi /mnt/boot/EFI/BOOT/BOOTX64.EFI
    changed=1
  fi

  return $changed
}
