: "${my_var:=}"

configure() {
  local changed=0
  local example_target="/mnt/etc/example.conf"
  local example_src
  example_src="$(script_dir)/example.conf"

  ensure_file_content "$example_src" "$example_target" || changed=1
  ensure_file_permissions 644 "$example_target" || changed=1

  return $changed
}
