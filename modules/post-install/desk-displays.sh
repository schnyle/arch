: "${system_user:=}"

configure_desk_displays() {
  require_var system_user

  local changed=0

  if [[ ! -f "/mnt/home/$system_user/.screenlayout/display.sh" ]]; then
    log "configuring desk displays"
    mkdir -p "/mnt/home/$system_user/.screenlayout"
    cat >"/mnt/home/$system_user/.screenlayout/display.sh" <<"EOF"
#!/bin/sh
xrandr --output HDMI-0 --mode 1920x1080 --pos 4480x354 --rotate normal --output DP-0 --off --output DP-1 --off --output DP-2 --mode 1920x1080 --pos 0x354 --rotate normal --output DP-3 --off --output DP-4 --primary --mode 2560x1440 --pos 1920x0 --rotate normal --output DP-5 --off
EOF
    changed=1
  fi

  if [[ $(stat -c "%a" "/mnt/home/$system_user/.screenlayout/display.sh") != "700" ]]; then
    log "setting permissions for screen layout config file"
    chmod 700 "/mnt/home/$system_user/.screenlayout/display.sh"
    changed=1
  fi

  return $changed
}
