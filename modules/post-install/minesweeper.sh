minesweeper_url="https://github.com/schnyle/minesweeper/releases/latest/download/minesweeper"

configure_minesweeper() {
  local changed=0

  if [[ ! -x /mnt/opt/minesweeper/minesweeper ]]; then
    log "installing minesweeper"
    mkdir -p /mnt/opt/minesweeper
    curl -fsSL --remove-on-error "$minesweeper_url" -o /mnt/opt/minesweeper/minesweeper
    chmod +x /mnt/opt/minesweeper/minesweeper
    changed=1
  fi

  if [[ $(readlink /mnt/usr/local/bin/minesweeper 2>/dev/null) != /opt/minesweeper/minesweeper ]]; then
    log "creating minesweeper symlink"
    ln -sf /opt/minesweeper/minesweeper /mnt/usr/local/bin/minesweeper
    changed=1
  fi

  return $changed
}
