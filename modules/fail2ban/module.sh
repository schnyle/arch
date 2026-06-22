: "${ssh_port:=}"

pacman_packages=(fail2ban)

configure() {
  local changed=0

  local rendered
  rendered=$(mktemp)
  sed "s/__SSH_PORT__/$ssh_port/" "$(script_dir)/jail.local" >"$rendered"
  ensure_file_content "$rendered" /etc/fail2ban/jail.local || changed=1
  rm -f "$rendered"

  ensure_service_enabled fail2ban || changed=1

  return $changed
}
