host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

log_file="/var/log/arch-install.log"
init_logging "$log_file"

if [[ -d /run/archiso ]]; then
  read -rp "live ISO detected - run bootstrapping (disk setup and fstab generation)? (yes/no): " ans
  if [[ $ans == "yes" ]]; then
    install_device=$(get_install_device)
    (source "$repo_root/bootstrap.sh") || die "bootstrap failed"
  fi

  mountpoint -q /mnt || die "/mnt not mounted - run bootstrap or mount the target first"
  mkdir -p "/mnt$repo_root"
  cp -a "$repo_root/." "/mnt$repo_root"
  arch-chroot /mnt bash "$repo_root/post-install.sh" "$host" "$repo_root"
else
  bash "$repo_root/post-install.sh" "$host" "$repo_root"
fi

log "done"

[[ -d /run/archiso ]] && mountpoint -q /mnt && cp "$log_file" "/mnt$log_file"
