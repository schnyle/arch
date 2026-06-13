# Minesweeper binary is installed, executable, and has a symlink.

configure() {
  local changed=0
  local minesweeper_url="https://github.com/schnyle/minesweeper/releases/latest/download/minesweeper"
  local minesweeper_bin="/opt/minesweeper/minesweeper"

  ensure_directory "/opt/minesweeper" || changed=1

  if [[ ! -f $minesweeper_bin ]]; then
    log "downloading minesweeper"
    curl -fsSL --remove-on-error "$minesweeper_url" -o "$minesweeper_bin"
    changed=1
  fi

  ensure_file_permissions 755 "$minesweeper_bin" || changed=1
  ensure_symlink "/opt/minesweeper/minesweeper" "/usr/local/bin/minesweeper" || changed=1

  return $changed
}
