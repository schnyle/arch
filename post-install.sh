: "${post_install_modules:=}"
: "${temp_sudoersd_file:=}"

host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

module_packages=()
get_pacman_packages module_packages "${post_install_modules[@]}"
pacman_packages+=("${module_packages[@]}")
mapfile -t pacman_packages < <(printf '%s\n' "${pacman_packages[@]}" | sort -u | grep .)
handle_unknown_pacman_packages pacman_packages

if [[ ${#post_install_modules[@]} -gt 0 || ${#pacman_packages[@]} -gt 0 ]]; then
  [[ ${#pacman_packages[@]} -gt 0 ]] && install_pacman_packages "${pacman_packages[@]}"
  [[ ${#post_install_modules[@]} -gt 0 ]] && converge_modules_unordered post-install "${post_install_modules[@]}"
else
  log "nothing to do, skipping"
fi

# remove the temporary passwordless sudo entry set up by the user module
[[ -f "$temp_sudoersd_file" ]] && rm -f "$temp_sudoersd_file"
