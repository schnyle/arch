: "${install_device:=}"
: "${boot_size:=}"
: "${swap_size:=}"

partitions_layout() {
  cat <<EOF
label: gpt
,$boot_size,U
,$swap_size,S
,,L
write
EOF
}

partitions_has_expected_layout() {
  local device=$1
  local types
  types=$(sfdisk -d "$device" 2>/dev/null | grep -oP 'type=\K\S+')

  echo "$types" | grep -q "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" || return 1 # EFI
  echo "$types" | grep -q "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" || return 1 # swap
  echo "$types" | grep -q "0FC63DAF-8483-4772-8E79-3D69D8477DE4" || return 1 # Linux
  [[ $(echo "$types" | wc -l) -eq 3 ]]                                       # exactly 3 entries
}

configure() {
  require_var install_device boot_size swap_size

  partitions_has_expected_layout "$install_device" && return 0

  if lsblk -n "$install_device" | grep -q part; then
    log "removing partitions from $install_device"
    wipefs -a "$install_device"
  fi

  log "writing partition layout to $install_device"
  partitions_layout | sfdisk "$install_device"

  return 1
}
