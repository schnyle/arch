configure() {
  local changed=0

  local dir file url resp
  dir="/opt/exiled-exchange-2"
  file="$dir/Exiled-Exchange-2.AppImage"

  ensure_directory "$dir" || changed=1

  if [[ ! -f "$file" ]]; then
    log "downloading Exiled-Exchange-2"
    if ! resp=$(curl -fsSL https://api.github.com/repos/Kvan7/Exiled-Exchange-2/releases/latest); then
      log "ERROR: failed to fetch Exiled-Exchange-2 release info"
      return 1
    fi

    url=$(grep -oP '"browser_download_url":\s*"\K[^"]*\.AppImage' <<<"$resp")
    if [[ -z "$url" ]]; then
      log "ERROR: could not resolve Exiled-Exchange-2 url"
      return 1
    fi

    if ! curl -fsSL --remove-on-error -o "$file" "$url"; then
      log "ERROR: failed to download Exiled-Exchange-2"
      return 1
    fi
    changed=1
  fi

  ensure_file_permissions 755 "$file" || changed=1

  local rendered
  rendered=$(mktemp)
  printf "#!/usr/bin/bash\nexec %s --no-overlay\n" "$file" >"$rendered"
  ensure_file_content "$rendered" "/usr/local/bin/exiled-exchange-2" || changed=1
  ensure_file_permissions 755 "/usr/local/bin/exiled-exchange-2" || changed=1
  rm -f "$rendered"

  return $changed
}
