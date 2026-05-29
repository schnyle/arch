# configuration
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_file="/home/kyle/repos/arch/test/log"

bootstrap_modules=(
  disk
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

install_device=$(select_install_device)
confirm_wipe_device "$install_device"
log "installing to $install_device"

# execution
source_modules "$repo_root" "${bootstrap_modules[@]}"
run_modules "${bootstrap_modules[@]}"

source_modules "$repo_root" "${regular_modules[@]}"
install_all_pacman_packages
converge_modules "${regular_modules[@]}"

source_modules "$repo_root" "${cleanup_modules[@]}"
run_modules "${cleanup_modules[@]}"

log "done"
