: "${install_device:=}"
: "${boot_size:=}"
: "${swap_size:=}"

max_attempts=5
install_device_prefix=$(partition_prefix "$install_device")

# partition the disk

# TODO specify partition layout at host
partitions_layout() {
  cat <<EOF
label: gpt
,$boot_size,U
,$swap_size,S
,,L
write
EOF
}

disk_is_partitioned() {
  local types
  types=$(sfdisk -d "$install_device" 2>/dev/null | grep -oP 'type=\K\S+')

  echo "$types" | grep -q "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" || return 1 # EFI
  echo "$types" | grep -q "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" || return 1 # swap
  echo "$types" | grep -q "0FC63DAF-8483-4772-8E79-3D69D8477DE4" || return 1 # Linux
  [[ $(echo "$types" | wc -l) -eq 3 ]]                                       # exactly 3 entries
}

attempt=0
until disk_is_partitioned; do
  ((attempt++ < max_attempts)) || die "failed to partition the disk after $max_attempts attempts"
  log "writing partition layout to $install_device (attempt $attempt)"
  partitions_layout | sfdisk --wipe-partitions=always "$install_device"
  partprobe "$install_device"
done

# format the partitions

filesystems_are_formatted() {
  [[ $(blkid -o value -s TYPE "${install_device_prefix}1" 2>/dev/null) == "vfat" ]] || return 1
  [[ $(blkid -o value -s TYPE "${install_device_prefix}2" 2>/dev/null) == "swap" ]] || return 1
  [[ $(blkid -o value -s TYPE "${install_device_prefix}3" 2>/dev/null) == "ext4" ]] || return 1
}

attempt=0
until filesystems_are_formatted; do
  ((attempt++ < max_attempts)) || die "failed to format the partitions after $max_attempts attempts"
  log "formatting partitions (attempt $attempt)"
  mkfs.fat -F32 "${install_device_prefix}1"
  mkswap "${install_device_prefix}2"
  mkfs.ext4 "${install_device_prefix}3"
done

# mount the file systems

mounts_are_active() {
  [[ $(findmnt -no SOURCE /mnt) == "${install_device_prefix}3" ]] || return 1
  [[ $(findmnt -no SOURCE /mnt/boot) == "${install_device_prefix}1" ]] || return 1
  swapon --show=NAME --noheadings | grep -q "^${install_device_prefix}2$" || return 1
}

attempt=0
until mounts_are_active; do
  ((attempt++ < max_attempts)) || die "failed to mount the file systems after $max_attempts attempts"
  log "mounting partitions (attempt $attempt)"
  mount "${install_device_prefix}3" /mnt
  mount --mkdir "${install_device_prefix}1" /mnt/boot
  swapon "${install_device_prefix}2"
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
