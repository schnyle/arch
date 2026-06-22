[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

repo_root="/arch-install"

# parse args
skip_clone=
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
    echo "Error: $repo_root is a mount point. Use --skip-clone or unmount first" && exit 1
  fi
  rm -rf "$repo_root"

  pacman -Sy
  pacman -S --noconfirm --needed git
  git clone https://github.com/schnyle/arch.git "$repo_root"
fi

bash "$repo_root/run/main.sh" "$repo_root" "$host"
