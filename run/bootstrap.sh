: "${partition_layout:=}"

max_attempts=5

# prompt user for installation device
install_device=$(get_install_device)
install_device_prefix=$(partition_prefix "$install_device")

if [[ -n $(wipefs -n "$install_device") ]]; then
  while read -r part; do
    wipefs -a "$part"
  done < <(lsblk -lnpo NAME "$install_device" | tail -n +2)
  sgdisk -Z "$install_device"
fi

# partition the disk

fstype_to_guid() {
  case $1 in
  fat32) echo "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" ;;
  swap) echo "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" ;;
  ext4) echo "0FC63DAF-8483-4772-8E79-3D69D8477DE4" ;;
  *) die "unknown fstype: $1" ;;
  esac
}

disk_is_partitioned() {
  local -a want actual
  local partition parts fstype

  for partition in "${partition_layout[@]}"; do
    IFS=":" read -ra parts <<<"$partition"
    fstype="${parts[1]}"
    want+=("$(fstype_to_guid "$fstype")")
  done

  mapfile -t actual < <(sfdisk -d "$install_device" 2>/dev/null | grep -oiP "type=\K[0-9A-F-]+")

  [[ "${want[*]}" == "${actual[*]}" ]]
}

make_partitions() {
  sgdisk -Z "$install_device"

  local n=1 partition size fstype end guid
  for partition in "${partition_layout[@]}"; do
    IFS=":" read -r size fstype _ <<<"${partition}"
    end="${size:+"+$size"}"
    guid=$(fstype_to_guid "$fstype")
    sgdisk -n "${n}:0:$end" -t "${n}:$guid" "$install_device" || return 1
    n=$((n + 1))
  done

  partprobe "$install_device"
}

attempt=0
until disk_is_partitioned; do
  ((attempt++ < max_attempts)) || die "failed to partition the disk after $max_attempts attempts"
  log "writing partition layout to $install_device (attempt $attempt)"
  make_partitions
done

# format the partitions

fstype_to_blkid() {
  case $1 in
  fat32) echo "vfat" ;;
  swap) echo "swap" ;;
  ext4) echo "ext4" ;;
  *) die "unknown fstype: $1" ;;
  esac
}

filesystems_are_formatted() {
  local -a want actual
  local partition fstype

  for partition in "${partition_layout[@]}"; do
    IFS=":" read -r _ fstype _ <<<"${partition}"
    want+=("$(fstype_to_blkid "$fstype")")
  done

  mapfile -t actual < <(lsblk -nro FSTYPE "$install_device" | tail -n +2)

  [[ "${want[*]}" == "${actual[*]}" ]]
}

make_filesystem() {
  local device="$1" fstype="$2"

  case $fstype in
  fat32) mkfs.fat -F32 "$device" ;;
  ext4) mkfs.ext4 -F "$device" ;;
  swap) mkswap -f "$device" ;;
  *) die "unknown fstype: $fstype" ;;
  esac
}

format_partitions() {
  local n=1 partition fstype device
  for partition in "${partition_layout[@]}"; do
    IFS=":" read -r _ fstype _ <<<"$partition"
    device="$install_device_prefix$n"
    make_filesystem "$device" "$fstype"
    n=$((n + 1))
  done
}

attempt=0
until filesystems_are_formatted; do
  ((attempt++ < max_attempts)) || die "failed to format the partitions after $max_attempts attempts"
  log "formatting partitions (attempt $attempt)"
  format_partitions
done

# mount the file systems

mounts_are_active() {
  local n=1 partition mount device
  for partition in "${partition_layout[@]}"; do
    IFS=":" read -r _ _ mount <<<"$partition"
    device="$install_device_prefix$n"
    if [[ "$mount" == swap ]]; then
      swapon --show=NAME --noheadings | grep -qxF "$device" || return 1
    else
      [[ $(findmnt -no SOURCE "/mnt$mount") == "$device" ]] || return 1
    fi
    n=$((n + 1))
  done
}

mount_partitions() {
  local -a fs_mounts swaps
  local n=1 partition mount device
  for partition in "${partition_layout[@]}"; do
    IFS=":" read -r _ _ mount <<<"$partition"
    device="$install_device_prefix$n"
    if [[ "$mount" == swap ]]; then
      swaps+=("$device")
    else
      fs_mounts+=("$mount $device")
    fi
    n=$((n + 1))
  done

  while read -r mount device; do
    findmnt -no SOURCE "/mnt$mount" &>/dev/null || mount --mkdir "$device" "/mnt$mount"
  done < <(printf '%s\n' "${fs_mounts[@]}" | sort)

  local s
  for s in "${swaps[@]}"; do
    swapon --show=NAME --noheadings | grep -qxF "$s" || swapon "$s"
  done
}

attempt=0
until mounts_are_active; do
  ((attempt++ < max_attempts)) || die "failed to mount the file systems after $max_attempts attempts"
  log "mounting partitions (attempt $attempt)"
  mount_partitions
done

# install essential packages

essential_packages=(
  base
  linux
  linux-firmware
  sudo
)

essential_packages_are_installed() {
  arch-chroot /mnt pacman -Q "${essential_packages[@]}" &>/dev/null
}

attempt=0
until essential_packages_are_installed; do
  ((attempt++ < max_attempts)) || die "failed to install essential packages after $max_attempts attempts"
  log "installing essential packages (attempt $attempt)"
  pacstrap /mnt "${essential_packages[@]}"
done

# fstab

fstab_is_generated() {
  grep -q "^UUID=" /mnt/etc/fstab
}

attempt=0
until fstab_is_generated; do
  ((attempt++ < max_attempts)) || die "failed to generate fstab after $max_attempts attempts"
  log "generating fstab (attempt $attempt)"
  genfstab -U /mnt >/mnt/etc/fstab
done
