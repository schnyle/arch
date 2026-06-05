: "${system_user:=}"

gtk_pacman_packages=(
  gnome-themes-extra
)
add_pacman_packages "${gtk_pacman_packages[@]}"

gtk_settings=$(
  cat <<"EOF"
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=true
EOF
)

gtk3_config="/mnt/home/$system_user/.config/gtk-3.0/settings.ini"
gtk4_config="/mnt/home/$system_user/.config/gtk-4.0/settings.ini"

configure_gtk() {
  require_var system_user

  local changed=0

  if [[ "$(cat "$gtk3_config" 2>/dev/null)" != "$gtk_settings" ]]; then
    log "configuring GTK 3.0 dark mode"
    mkdir -p "/mnt/home/$system_user/.config/gtk-3.0"
    echo "$gtk_settings" >"$gtk3_config"
    changed=1
  fi

  if [[ "$(cat "$gtk4_config" 2>/dev/null)" != "$gtk_settings" ]]; then
    log "configuring GTK 4.0 dark mode"
    mkdir -p "/mnt/home/$system_user/.config/gtk-4.0"
    echo "$gtk_settings" >"$gtk4_config"
    changed=1
  fi

  return $changed
}
