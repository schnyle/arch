# GTK applications use the Adwaita-dark theme.

: "${system_user:=}"

configure() {
  local changed=0
  local settings_src="$(script_dir)/settings.ini"
  local gtk3_config="/home/$system_user/.config/gtk-3.0/settings.ini"
  local gtk4_config="/home/$system_user/.config/gtk-4.0/settings.ini"

  ensure_file_content -u "$system_user" "$settings_src" "$gtk3_config" || changed=1
  ensure_file_content -u "$system_user" "$settings_src" "$gtk4_config" || changed=1

  return $changed
}
