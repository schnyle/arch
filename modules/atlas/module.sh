: "${system_user:=}"

get_snapshot_device() {
  local device
  while true; do
    echo "available devices:" >&2
    lsblk -d -o NAME,SIZE,TYPE | grep disk >&2
    echo >&2
    read -r -p "enter snapshot device name (omit '/dev/'): " device
    device="/dev/$device"

    if [[ ! -b "$device" ]]; then
      echo "device '$device' not found, try again" >&2
      continue
    fi

    if [[ $(lsblk -dno FSTYPE "$device") != "ext4" ]]; then
      echo "device $device is not ext4 formatted. Select a different device, or format $device properly and restart." >&2
      continue
    fi

    break
  done

  echo "$device"
}

configure() {
  local changed=0

  # /storage setup
  local storage_dirs=(
    docs
    media
    misc
    repos
  )

  for dir in "${storage_dirs[@]}"; do
    ensure_directory "/storage/$dir" || changed=1
    ensure_file_ownership -R "$system_user:$system_user" "/storage/$dir" || changed=1
    ensure_file_permissions 755 "/storage/$dir" || changed=1
  done

  # /snapshots setup
  if ! grep -q " /snapshots " /etc/fstab; then
    local device uuid
    device=$(get_snapshot_device)
    uuid=$(blkid -o value -s UUID "$device")
    echo "UUID=$uuid /snapshots ext4 defaults 0 2" >>/etc/fstab
    changed=1
  fi

  if ! mountpoint -q /snapshots; then
    mkdir -p /snapshots
    mount /snapshots
    changed=1
  fi

  ensure_file_permissions 755 /snapshots || changed=1
  if [[ ! -d /snapshots/initial ]]; then
    log "creating initial snapshot baseline"
    mkdir /snapshots/initial
    changed=1
  fi

  if [[ ! -L /snapshots/latest ]]; then
    log "bootstrapping latest snapshot pointer"
    ln -sfn /snapshots/initial /snapshots/latest
    changed=1
  fi

  # atlas-snapshot script
  ensure_file_content "$(script_dir)/atlas-snapshot" /usr/local/bin/atlas-snapshot || changed=1
  ensure_file_ownership root:root /usr/local/bin/atlas-snapshot || changed=1
  ensure_file_permissions 755 /usr/local/bin/atlas-snapshot || changed=1

  # atlas-snapshot service
  ensure_file_content "$(script_dir)/atlas-snapshot.service" /etc/systemd/system/atlas-snapshot.service || changed=1
  ensure_file_ownership root:root /etc/systemd/system/atlas-snapshot.service || changed=1
  ensure_file_permissions 644 /etc/systemd/system/atlas-snapshot.service || changed=1

  # atlas-snapshot timer
  ensure_file_content "$(script_dir)/atlas-snapshot.timer" /etc/systemd/system/atlas-snapshot.timer || changed=1
  ensure_file_ownership root:root /etc/systemd/system/atlas-snapshot.timer || changed=1
  ensure_file_permissions 644 /etc/systemd/system/atlas-snapshot.timer || changed=1

  # atlas-restore script
  ensure_file_content "$(script_dir)/atlas-restore" /usr/local/bin/atlas-restore || changed=1
  ensure_file_ownership root:root /usr/local/bin/atlas-restore || changed=1
  ensure_file_permissions 755 /usr/local/bin/atlas-restore || changed=1

  [[ $changed -eq 1 ]] && systemctl daemon-reload
  ensure_service_enabled atlas-snapshot.timer || changed=1

  return $changed
}
