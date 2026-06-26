repo_root="$1"

declare -A valid_fstypes=(
  [fat32]=1
  [swap]=1
  [ext4]=1
)

has_modules_or_pacman_packages() {
  grep -qE "^modules=\(|^pacman_packages=\(" "$1"
}

all_modules_exist() {
  ! declare -p modules &>/dev/null && return 0

  local fail=0
  for module in "${modules[@]}"; do
    if [[ ! -d "$repo_root/modules/$module" ]]; then
      echo "error: $host_name host declares unknown module '$module'" >&2
      fail=1
    fi
  done

  return $fail
}

is_valid_disk_layout() {
  ! declare -p disk_layout &>/dev/null && return 0

  local -a layout=("${disk_layout[@]}") fail=0 parts
  if [[ ${#layout[@]} -eq 0 ]]; then
    echo "error: empty disk layout string" >&2
    fail=1
  fi

  local last=$((${#layout[@]} - 1))
  local i size fstype mount

  for i in "${!layout[@]}"; do
    IFS=":" read -ra parts <<<"${layout[i]}"
    if [[ ${#parts[@]} -ne 3 ]]; then
      echo "expected 3 fields, got ${#parts[@]}: '${layout[i]}'" >&2
      fail=1
      continue
    fi

    size=${parts[0]}
    fstype=${parts[1]}
    mount=${parts[2]}

    if [[ -z $size ]]; then
      if [[ $i -ne $last ]]; then
        echo "empty size only allowed on the last partition: '${layout[i]}'" >&2
        fail=1
      fi
    else
      if [[ ! $size =~ ^[0-9]+([KMGTP])?$ ]]; then
        echo "invalid size: '${layout[i]}'" >&2
        fail=1
      fi
    fi

    if [[ -z "${valid_fstypes[$fstype]}" ]]; then
      echo "invalid fstype: '${layout[i]}'" >&2
      fail=1
    fi

    if [[ $mount != /* && $mount != swap ]]; then
      echo "invalid mount: '${layout[i]}'" >&2
      fail=1
    fi
  done

  return $fail
}

fail=0
for host_file in "$repo_root"/hosts/*.sh; do
  host_name=$(basename "$host_file" .sh)

  unset disk_layout modules pacman_packages
  source "$host_file"

  if ! is_valid_disk_layout; then
    echo "error: $host_name host contains an invalid disk layout"
    fail=1
  fi

  if ! has_modules_or_pacman_packages "$host_file"; then
    echo "error: $host_name host does not contain modules=() or pacman_packages=() (needs at least one)" >&2
    fail=1
    continue
  fi

  if ! all_modules_exist; then
    echo "error: $host_name host contains undefined module(s)"
    fail=1
  fi
done

exit $fail
