: "${install_device:=}"

configure_mounts() {
  require_var install_device

  local prefix=$install_device
  if [[ $install_device =~ nvme ]]; then
    # NVMe drives use 'p' separator for partition numbers (e.g., /dev/nvme0n1p1)
    prefix="${install_device}p"
  fi

  mounts_active "$prefix" && return 0

  log "mounting partitions"
  mount "${prefix}3" /mnt
  mount --mkdir "${prefix}1" /mnt/boot
  swapon "${prefix}2"

  mounts_active "$prefix" || return 1
}

mounts_active() {
  local prefix=$1
  [[ $(findmnt -no SOURCE /mnt) == "${prefix}3" ]] || return 1
  [[ $(findmnt -no SOURCE /mnt/boot) == "${prefix}1" ]] || return 1
  swapon --show=NAME --noheadings | grep -q "${prefix}2" || return 1
}
