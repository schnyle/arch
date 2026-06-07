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

  local dirs_path="/mnt/home/$system_user/.config/user-dirs.dirs"
  ensure_file_content "$(script_dir)/user-dirs.dirs" "$dirs_path" || changed=1
  ensure_file_ownership "$system_user:$system_user" "$dirs_path"

  local conf_path="/mnt/home/$system_user/.config/user-dirs.conf"
  ensure_file_content "$(script_dir)/user-dirs.conf" "$conf_path" || changed=1
  ensure_file_ownership "$system_user:$system_user" "$conf_path"

  for dir in "${home_dirs[@]}"; do
    local path="/mnt/home/$system_user/$dir"

    if ! [[ -d "$path" ]]; then
      log "creating $dir user home directory"
      mkdir -p "$path"
      changed=1
    fi

    ensure_file_ownership "$system_user:$system_user" "$path" || changed=1
  done

  return $changed
}
