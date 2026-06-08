: "${is_live_env:=}"

host="desk" # will pass in from bootstrap.sh
log_file="/var/log/arch-install.log"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$repo_root/lib/init.sh"

init_logging "$log_file"

if [[ -n $is_live_env ]]; then
  bash "$repo_root/install.sh" "$host"
  mkdir -p /mnt/arch-install
  mount --bind "$repo_root" /mnt/arch-install
  trap "umount /mnt/arch-install" EXIT
  arch-chroot /mnt bash /arch-install/post-install.sh "$host"
else
  bash "$repo_root/post-install.sh" "$host"
fi

log "done"

[[ -n $is_live_env ]] && cp "$log_file" "/mnt$log_file"
