# Desk monitor xrandr layout script is installed at ~/.screenlayout/display.sh.

: "${system_user:=}"

configure() {
  local changed=0
  local path="/mnt/home/$system_user/.screenlayout/display.sh"

  ensure_file_content "$(script_dir)/display.sh" "$path" || changed=1
  ensure_file_permissions 700 "$path" || changed=1
  ensure_file_ownership -R "$system_user:$system_user" "$(dirname "$path")"

  return $changed
}
