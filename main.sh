: "${is_live_env:=}"

host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

log_file="/var/log/arch-install.log"
init_logging "$log_file"

if [[ -n $is_live_env ]]; then
  bash "$repo_root/install.sh" "$host" "$repo_root"

  chroot_repo_root="/mnt$repo_root"
  mkdir -p "$chroot_repo_root"
  mount --bind "$repo_root" "$chroot_repo_root"
  trap "umount $chroot_repo_root" EXIT
  arch-chroot /mnt bash "$repo_root/post-install.sh" "$host" "$repo_root"
else
  bash "$repo_root/post-install.sh" "$host" "$repo_root"
fi

log "done"

[[ -n $is_live_env ]] && cp "$log_file" "/mnt$log_file"
