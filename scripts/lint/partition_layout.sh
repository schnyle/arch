declare -A valid_fstypes=(
  [fat32]=1
  [swap]=1
  [ext4]=1
)

fail=0
err() {
  echo "✗ $*" >&2
  fail=1
}

is_valid_partition_layout() {
  local -a layout=("$@") parts
  if [[ ${#layout[@]} -eq 0 ]]; then
    err "empty partition layout"
    return
  fi

  local last=$((${#layout[@]} - 1))
  local i size fstype mount

  for i in "${!layout[@]}"; do
    IFS=":" read -ra parts <<<"${layout[i]}"
    if [[ ${#parts[@]} -ne 3 ]]; then
      err "expected 3 fields, got ${#parts[@]}: '${layout[i]}'"
      continue
    fi

    size=${parts[0]}
    fstype=${parts[1]}
    mount=${parts[2]}

    if [[ -z $size ]]; then
      [[ $i -eq $last ]] || err "empty size only allowed on the last partition: '${layout[i]}'"
    else
      [[ $size =~ ^[0-9]+([KMGTP])?$ ]] || err "invalid size: '${layout[i]}'"
    fi

    [[ -n "${valid_fstypes[$fstype]}" ]] || err "invalid fstype: '${layout[i]}'"

    [[ $mount == /* || $mount == swap ]] || err "invalid mount: '${layout[i]}'"
  done
}

repo_root=$(git rev-parse --show-toplevel)
for host in "$repo_root"/hosts/*.sh; do
  unset partition_layout
  source "$host"
  if declare -p partition_layout &>/dev/null; then
    is_valid_partition_layout "${partition_layout[@]}"
  fi
done

exit $fail
