# DUPLICATED FROM modules/install/mounts — see TODO
: "${install_device:=}"

mounts_active() {
  local prefix=$1
  [[ $(findmnt -no SOURCE /mnt) == "${prefix}3" ]] || return 1
  [[ $(findmnt -no SOURCE /mnt/boot) == "${prefix}1" ]] || return 1
  [[ $(findmnt -no SOURCE /mnt/storage) == "${prefix}4" ]] || return 1
  swapon --show=NAME --noheadings | grep -q "^${prefix}2$" || return 1
}

configure() {
  local prefix
  prefix=$(partition_prefix "$install_device")

  mounts_active "$prefix" && return 0

  log "mounting partitions"
  mount "${prefix}3" /mnt
  mount --mkdir "${prefix}1" /mnt/boot
  mount --mkdir "${prefix}4" /mnt/mnt/storage
  swapon "${prefix}2"

  return 1
}
