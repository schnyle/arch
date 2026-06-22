: "${system_user:=}"

configure() {
  local changed=0
  local sd
  sd=$(script_dir)

  ensure_file_content "$sd/atlas-snapshot" /usr/local/bin/atlas-snapshot || changed=1
  ensure_file_ownership root:root /usr/local/bin/atlas-snapshot || changed=1
  ensure_file_permissions 755 /usr/local/bin/atlas-snapshot || changed=1

  local rendered
  rendered=$(mktemp)
  sed "s/__SYSTEM_USER__/$system_user/" "$sd/atlas-snapshot.service" >"$rendered"
  ensure_file_content "$rendered" /etc/systemd/system/atlas-snapshot.service || changed=1
  rm -f "$rendered"
  ensure_file_ownership root:root /etc/systemd/system/atlas-snapshot.service || changed=1
  ensure_file_permissions 644 /etc/systemd/system/atlas-snapshot.service || changed=1

  ensure_file_content "$sd/atlas-snapshot.timer" /etc/systemd/system/atlas-snapshot.timer || changed=1
  ensure_file_ownership root:root /etc/systemd/system/atlas-snapshot.timer || changed=1
  ensure_file_permissions 644 /etc/systemd/system/atlas-snapshot.timer || changed=1

  [[ $changed -eq 1 ]] && systemctl daemon-reload
  ensure_service_enabled atlas-snapshot.timer || changed=1

  return $changed
}
