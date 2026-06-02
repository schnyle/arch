# configuration
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
boot_size="512M"
swap_size="2G"
time_zone="/usr/share/zoneinfo/America/Denver"
hostname="desk$(date '+%Y%m%d')"

log_file="/home/kyle/repos/arch/test/log"

bootstrap_modules=(
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

regular_modules=(
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
log "running bootstrap modules"
source_modules "$repo_root" "${bootstrap_modules[@]}"
run_modules "${bootstrap_modules[@]}"

# log "running regular modules"
# source_modules "$repo_root" "${regular_modules[@]}"
# install_all_pacman_packages
# converge_modules "${regular_modules[@]}"
#
# log "running cleanup modules"
# source_modules "$repo_root" "${cleanup_modules[@]}"
# run_modules "${cleanup_modules[@]}"

log "done"
