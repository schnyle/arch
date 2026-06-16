# Home directory is organized with XDG mappings and canonical subdirs.

: "${system_user:=}"

configure() {
  local changed=0

  local home_dirs=(
    docs
    media
    misc
    repos
  )

  local dirs_path="/home/$system_user/.config/user-dirs.dirs"
  ensure_file_content -u "$system_user" "$(script_dir)/user-dirs.dirs" "$dirs_path" || changed=1

  local conf_path="/home/$system_user/.config/user-dirs.conf"
  ensure_file_content -u "$system_user" "$(script_dir)/user-dirs.conf" "$conf_path" || changed=1

  for dir in "${home_dirs[@]}"; do
    local path="/home/$system_user/$dir"
    ensure_directory -u "$system_user" "$path" || changed=1
    ensure_file_ownership "$system_user:$system_user" "$path" || changed=1
  done

  return $changed
}
