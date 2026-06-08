host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

log "starting install"
install_device=$(get_install_device)
validate_required_vars "install" "${install_modules[@]}"
log "installing to $install_device"
converge_modules_ordered install "${install_modules[@]}"
