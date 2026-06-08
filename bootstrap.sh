[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

# TODO: clone git repo to /tmp/arch-install
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # will be /tmp/arch-install

hosts=()
for f in "$repo_root"/hosts/*.sh; do
  hosts+=("$(basename "$f" .sh)")
done
if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "Error: no hosts found!"
  exit 1
fi

host=
while true; do
  echo "available hosts: ${hosts[*]}"
  echo
  read -r -p "enter host to install: " host

  [[ -f "$repo_root/hosts/$host.sh" ]] && break

  echo "Host '$host' not available."
  continue
done

bash "$repo_root/main.sh" "$host" "$repo_root"
