repo_root="$1"

module_sh_exists() {
  [[ -f "$1/module.sh" ]]
}

configure_or_pacman_packages() {
  grep -qE "^configure[[:space:]]*\(\)|^pacman_packages=\(" "$1"
}

fail=0
for module_dir in "$repo_root"/modules/*/; do
  module_name=$(basename "$module_dir")

  if ! module_sh_exists "$module_dir"; then
    echo "error: $module_name module missing module.sh" >&2
    fail=1
    continue
  fi

  module_file="$module_dir/module.sh"

  if ! configure_or_pacman_packages "$module_file"; then
    echo "error: $module_name module does not contain configure() or pacman_packages=() (needs at least one)" >&2
    fail=1
  fi
done

exit $fail
