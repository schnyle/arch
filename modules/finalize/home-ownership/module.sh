: "${system_user:=}"

configure() {
  ensure_file_ownership -R "$system_user:$system_user" "/mnt/home/$system_user"
}
