: "${install_device:=}"

configure() {
  mountpoint -q /snapshots && return 0

  local device
  while true; do
    echo "select snapshot device:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    echo
    read -r -p "enter snapshot device name (omit '/dev/'): " device
    device="/dev/$device"

    if [[ "$device" == "$install_device" ]]; then
      echo "snapshot device cannot be the same as install device, try again"
      continue
    fi
    if [[ ! -b "$device" ]]; then
      echo "device '$device' not found, try again"
      continue
    fi
    break
  done

  lsblk -n "$device" | grep -q part &&
    die "snapshot device $device has partitions, expected none. Remove partitions and restart."
  [[ "$(lsblk -f -n -o FSTYPE "$device")" == "ext4" ]] ||
    die "snapshot device $device is not ext4 formatted. Format and restart."
  mount | grep -q "$device" &&
    die "snapshot device $device is already mounted. Unmount and restart."

  log "mounting snapshot device $device at /snapshots"
  mount --mkdir "$device" /snapshots

  ## TODO: ensure added to /etc/fstab
  return 1
}
