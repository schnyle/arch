# Desk monitor xrandr layout script is installed at ~/.screenlayout/display.sh.

: "${system_user:=}"

configure() {
  local changed=0
  local path="/home/$system_user/.screenlayout/display.sh"

  ensure_file_content -u "$system_user" "$(script_dir)/display.sh" "$path" || changed=1
  ensure_file_permissions 700 "$path" || changed=1

  return $changed
}
