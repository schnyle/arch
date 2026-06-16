: "${install_modules:=}"

host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

log "starting install"

if [[ ${#install_modules[@]} -gt 0 ]]; then
  install_device=$(get_install_device)
  validate_required_vars "install" "${install_modules[@]}"
  log "installing to $install_device"
  converge_modules_ordered install "${install_modules[@]}"
else
  log "nothing to do, skipping"
fi
