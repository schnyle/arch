: "${install_device:=}"

filesystems_present() {
  local prefix=$1
  [[ $(blkid -o value -s TYPE "${prefix}1" 2>/dev/null) == "vfat" ]] || return 1
  [[ $(blkid -o value -s TYPE "${prefix}2" 2>/dev/null) == "swap" ]] || return 1
  [[ $(blkid -o value -s TYPE "${prefix}3" 2>/dev/null) == "ext4" ]] || return 1
}

configure_filesystems() {
  require_var install_device

  local prefix
  prefix=$(partition_prefix "$install_device")

  filesystems_present "$prefix" && return 0

  log "formatting partitions"
  mkfs.fat -F32 "${prefix}1"
  mkswap "${prefix}2"
  mkfs.ext4 "${prefix}3"
  return 1
}
