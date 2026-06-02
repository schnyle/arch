# configuration
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
boot_size="512M"
swap_size="2G"
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="desk$(date '+%Y%m%d')"

log_file="/home/kyle/repos/arch/test/log"

install_modules=(
  partitions
  filesystems
  mounts
  essential_packages
  mirrors
  fstab
  time
  localization
  hostname
  root_password
  bootloader
)

post_install_modules=(
  demo
  user
)

cleanup_modules=(
  cleanup
)

# initialization
source "$repo_root/lib/common.sh"
source_lib "$repo_root"

init_logging "$log_file"

install_device=$(get_install_device)
log "installing to $install_device"

# execution
log "running install modules"
source_modules "$repo_root" "${install_modules[@]}"
converge_ordered "${install_modules[@]}"

# log "running post-install modules"
# source_modules "$repo_root" "${post_install_modules[@]}"
# install_all_pacman_packages
# converge_unordered "${post_install_modules[@]}"
#
# log "running cleanup modules"
# source_modules "$repo_root" "${cleanup_modules[@]}"
# converge_ordered "${cleanup_modules[@]}"

log "done"
