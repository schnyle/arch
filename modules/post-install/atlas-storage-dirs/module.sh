: "${system_user:=}"

configure() {
  local changed=0

  local storage_dirs=(
    docs
    media
    misc
    repos
  )

  for dir in "${storage_dirs[@]}"; do
    ensure_directory "/storage/$dir" || changed=1
  done
  ensure_file_ownership -R "$system_user:$system_user" /storage || changed=1

  if find /storage -type d ! -perm 755 | grep -q .; then
    log "setting /storage dir permissions to 755"
    find /storage -type d -exec chmod 755 {} +
    changed=1
  fi

  ensure_file_permissions 755 /snapshots || changed=1
  if [[ ! -d /snapshots/initial ]]; then
    log "creating initial snapshot baseline"
    mkdir /snapshots/initial
    changed=1
  fi
  ensure_symlink /snapshots/initial /snapshots/latest || changed=1
  ensure_file_ownership -R "$system_user:$system_user" /snapshots || changed=1

  return $changed
}
