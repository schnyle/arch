get_install_device() {
  if mountpoint -q /mnt; then
    echo "/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /mnt)")"
    return
  fi

  local device
  device=$(select_install_device)
  confirm_wipe_device "$device"
  echo "$device"
}

select_install_device() {
  local install_device
  while true; do
    echo "available devices:" >&2
    lsblk -d -n -o NAME,SIZE,TYPE >&2
    echo >&2
    read -r -p "enter device name: " install_device
    install_device="/dev/$install_device"

    [[ -b "$install_device" ]] && break

    echo "device '$install_device' not found, try again" >&2
  done
  echo "$install_device"
}

confirm_wipe_device() {
  local device=$1
  local input
  if lsblk -n "$device" | grep -q part; then
    echo "WARNING: device $device is already partitioned" >&2
    lsblk "$device" >&2
    read -r -p "Continue? (yes/no): " input
    if [[ "$input" != "yes" ]]; then
      log "install aborted by user"
      exit 0
    fi
  fi
}

partition_prefix() {
  local install_device=$1
  local prefix="$install_device"

  # NVMe drives use 'p' separator for partition numbers (e.g., /dev/nvme0n1p1)
  [[ $install_device =~ nvme ]] && prefix="${install_device}p"

  echo "$prefix"
}
