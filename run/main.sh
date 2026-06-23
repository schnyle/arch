repo_root="$1"
host="$2"

# enumerate hosts
hosts=()
for f in "$repo_root"/hosts/*.sh; do
  hosts+=("$(basename "$f" .sh)")
done

if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "Error: no hosts found!"
  exit 1
fi

# determine host
if [[ -n $host ]]; then
  if [[ ! -f "$repo_root/hosts/$host.sh" ]]; then
    echo "Host '$host' not available. Available hosts: ${hosts[*]}"
    exit 1
  fi
else
  while true; do
    echo "available hosts: ${hosts[*]}"
    echo
    read -r -p "enter host to install: " host
    [[ -f "$repo_root/hosts/$host.sh" ]] && break
    echo "Host '$host' not available."
  done
fi
source "$repo_root/lib/init.sh"

log_file="/var/log/arch-install.log"
init_logging "$log_file"

if [[ -d /run/archiso ]]; then
  read -rp "live ISO detected - run bootstrapping (disk setup and fstab generation)? (yes/no): " ans
  if [[ $ans == "yes" ]]; then
    (source "$repo_root/run/bootstrap.sh") || die "bootstrap failed"
  fi

  mountpoint -q /mnt || die "/mnt not mounted - run bootstrap or mount the target first"
  mkdir -p "/mnt$repo_root"
  cp -a "$repo_root/." "/mnt$repo_root"
  arch-chroot /mnt bash "$repo_root/run/converge.sh" "$host" "$repo_root"
else
  bash "$repo_root/run/converge.sh" "$host" "$repo_root"
fi

log "done"

[[ -d /run/archiso ]] && mountpoint -q /mnt && cp "$log_file" "/mnt$log_file"
