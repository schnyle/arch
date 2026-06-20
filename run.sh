[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

repo_root="/arch-install"

# parse args
skip_clone=
host=
while [[ $# -gt 0 ]]; do
  case "$1" in
  --skip-clone)
    skip_clone=1
    shift
    ;;
  *)
    host="$1"
    shift
    ;;
  esac
done

# clone repo
if [[ -n $skip_clone ]]; then
  if [[ ! -d "$repo_root/.git" ]]; then
    echo "Error: repository not found at $repo_root"
    exit 1
  fi
else
  if mountpoint -q "$repo_root"; then
    echo "Error: $repo_root is a mount point. Use --skip-clone or unmount first"
  fi
  rm -rf "$repo_root"

  pacman -Sy
  pacman -S --noconfirm --needed git
  git clone https://github.com/schnyle/arch.git "$repo_root"
fi

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

bash "$repo_root/main.sh" "$host" "$repo_root"
