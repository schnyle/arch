host="$1"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$repo_root/lib/init.sh"

log "starting install"
install_device=$(get_install_device)
validate_required_vars "install" "${install_modules[@]}"
log "installing to $install_device"
converge_modules_ordered install "${install_modules[@]}"
