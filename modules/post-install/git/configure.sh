# git is installed with user.name and user.email configured.

: "${system_user:=}"
: "${git_name:=}"
: "${email:=}"

configure() {
  local changed=0

  if [[ $(sudo -u "$system_user" git config --global user.email) != "$email" ]]; then
    log "configuring $email as git config user.email"
    sudo -u "$system_user" git config --global user.email "$email"
    changed=1
  fi

  if [[ $(sudo -u "$system_user" git config --global user.name) != "$git_name" ]]; then
    log "configuring $git_name as git config user.name"
    sudo -u "$system_user" git config --global user.name "$git_name"
    changed=1
  fi

  return $changed
}
