host="$1"
repo_root="$2"

source "$repo_root/lib/init.sh"

pacman_packages=()
get_pacman_packages pacman_packages "${post_install_modules[@]}"

install_pacman_packages "${pacman_packages[@]}"
converge_modules_unordered post-install "${post_install_modules[@]}"

# remove the temporary passwordless sudo entry set up by the user module
[[ -f "$temp_sudoersd_file" ]] && rm -f "$temp_sudoersd_file"
