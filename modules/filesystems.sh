: "${install_device:=}"

configure_filesystems() {
  require_var install_device

  local prefix=$install_device
  if [[ $install_device =~ nvme ]]; then
    # NVMe drives use 'p' separator for partition numbers (e.g., /dev/nvme0n1p1)
    prefix="${install_device}p"
  fi

  filesystems_present "$prefix" && return 0

  log "formatting partitions"
  mkfs.fat -F32 "${prefix}1"
  mkswap "${prefix}2"
  mkfs.ext4 "${prefix}3"

  filesystems_present "$prefix" || return 1
}

filesystems_present() {
  local prefix=$1
  [[ $(blkid -o value -s TYPE "${prefix}1" 2>/dev/null) == "vfat" ]] || return 1
  [[ $(blkid -o value -s TYPE "${prefix}2" 2>/dev/null) == "swap" ]] || return 1
  [[ $(blkid -o value -s TYPE "${prefix}3" 2>/dev/null) == "ext4" ]] || return 1
}
