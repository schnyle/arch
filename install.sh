host="desk" # will pass in from bootstrap.sh
log_file="/var/log/arch-install.log"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host_dir="$repo_root/hosts/$host"

source "$repo_root/lib/common.sh"
source_lib "$repo_root"
init_logging "$log_file"

# create variables
source "$host_dir/vars.sh"

# get install device from user
install_device=$(get_install_device)
log "installing to $install_device"

# load modules
install_modules=()
load_modules "$host_dir/install" install_modules

post_install_modules=()
load_modules "$host_dir/post-install" post_install_modules

finalize_modules=()
load_modules "$host_dir/finalize" finalize_modules

# validate required vars
validate_required_vars "install" "${install_modules[@]}"
validate_required_vars "post-install" "${post_install_modules[@]}"
validate_required_vars "finalize" "${finalize_modules[@]}"

# execute install
log "running install modules"
converge_modules_ordered install "${install_modules[@]}"

log "running post-install modules"
pacman_packages=()
get_pacman_packages pacman_packages "${post_install_modules[@]}"
install_pacman_packages "${pacman_packages[@]}"
converge_modules_unordered post-install "${post_install_modules[@]}"

log "running finalize modules"
converge_modules_ordered finalize "${finalize_modules[@]}"

log "done"
