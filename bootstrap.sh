[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

pacman -Sy
pacman -S --noconfirm --needed git

repo_root="/tmp/arch-install"
rm -rf "$repo_root"
git clone --branch refactor/composable-modules https://github.com/schnyle/arch.git "$repo_root"

hosts=()
for f in "$repo_root"/hosts/*.sh; do
  hosts+=("$(basename "$f" .sh)")
done
if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "Error: no hosts found!"
  exit 1
fi

host="$1"
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
