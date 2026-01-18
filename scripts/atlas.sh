#!/bin/bash

# configuration file path
config_file="$HOME/.config/atlas.conf"

# default config file content
default_config=$(
  cat <<"EOF"
# Atlas config
host=192.168.122.74
remote_user=atlas
port=2222
remote_storage_dir=/storage

# path of SSH key to user for Atlas auth
sshkey=$HOME/.ssh/id_ed25519

# directories to sync (relative to $HOME)
dirs=docs,media,misc,repos
EOF
)

# help text
help_text=$(
  cat <<"EOF"
Usage: atlas <command> [options] [args]

Commands:
  upload <path>      Upload file/directory to atlas
  download <path>    Download file/directory from atlas
  status [path]      Show sync status
  list [path]        List remote files

Options:
  -h, --help         Show this help message

Examples:
  atlas upload ~/docs
  atlas status
  atlas list ~/media
EOF
)

load_config() {
  # load config
  if ! [[ -f "$config_file" ]]; then
    echo "config not found, creating default at $config_file"
    echo "$default_config" >"$config_file"
  fi

  # shellcheck disable=SC1090
  source "$config_file"

  # validate required keys
  if [[ -z "$host" ]]; then
    echo "error: 'host' not set in config" >&2
    exit 1
  fi
  if [[ -z "$remote_user" ]]; then
    echo "error: 'remote_user' not set in config" >&2
    exit 1
  fi
  if [[ -z "$port" ]]; then
    echo "error: 'port' not set in config" >&2
    exit 1
  fi
  if [[ -z "$remote_storage_dir" ]]; then
    echo "error: 'remote_storage_dir' not set in config" >&2
    exit 1
  fi
  if [[ -z "$sshkey" ]]; then
    echo "error: 'sshkey' not set in config" >&2
    exit 1
  fi
  if [[ -z "$dirs" ]]; then
    echo "error: 'dirs' not set in config" >&2
    exit 1
  fi

  # validate values
  if ! [[ -f "$sshkey" ]]; then
    echo "error: ssh key not found: $sshkey" >&2
    exit 1
  fi

  # parse dirs
  IFS="," read -ra managed_dirs <<<"$dirs"
}

parse_global_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      echo "$help_text"
      exit 0
      ;;
    -*)
      echo "unknown option: $1" >&2
      echo "run 'atlas --help' for usage" >&2
      exit 1
      ;;
    *)
      break
      ;;
    esac
    shift
  done
}

is_path_managed() {
  local canonical="$1"
  local base="$2"

  for dir in "${managed_dirs[@]}"; do
    managed_canonical="$base/$dir"
    if [[ "$canonical" == "$managed_canonical" ]] || [[ "$canonical" == "$managed_canonical"/* ]]; then
      return 0
    fi
  done

  echo "error: path not in managed directories: $canonical" >&2
  return 1
}

local_to_remote_path() {
  local local_path="$1"
  local local_home="$HOME"

  echo "${local_path/$local_home/$remote_storage_dir}"
}

remote_to_local_path() {
  local remote_path="$1"
  local local_home="$HOME"

  echo "${remote_path/$remote_storage_dir/$local_home}"
}

upload() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo "Usage: atlas upload <path>" >&2
    exit 1
  fi

  local local_canonical remote_canonical

  local_canonical=$(realpath -e "$path")
  if ! is_path_managed "$local_canonical" "$HOME"; then
    exit 1
  fi

  remote_canonical=$(local_to_remote_path "$local_canonical")

  if [[ -d "$local_canonical" ]]; then
    local_canonical="$local_canonical/"
    remote_canonical="$remote_canonical/"
  fi

  echo "Uploading: $local_canonical"
  echo "         → $remote_user@$host:$remote_canonical"

  if ! rsync -a --info=progress2 \
    -e "ssh -i '$sshkey' -p $port" \
    --mkpath \
    "$local_canonical" \
    "$remote_user@$host:$remote_canonical"; then
    echo "error: upload failed" >&2
    exit 1
  fi

  echo "upload complete"
}

download() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo "Usage: atlas download <path>" >&2
    exit 1
  fi

  local local_canonical remote_canonical

  remote_canonical="$path"
  if ! is_path_managed "$remote_canonical" "$remote_storage_dir"; then
    exit 1
  fi

  local_canonical=$(remote_to_local_path "$remote_canonical")

  if ssh -i "$sshkey" -p "$port" "$remote_user@$host" "test -d '$remote_canonical'"; then
    local_canonical="$local_canonical/"
    remote_canonical="$remote_canonical/"
  fi

  echo "Downloading: $remote_user@$host:$remote_canonical"
  echo "           → $local_canonical"

  if ! rsync -a --info=progress2 \
    -e "ssh -i '$sshkey' -p $port" \
    "$remote_user@$host:$remote_canonical" \
    "$local_canonical"; then
    echo "error: download failed" >&2
    exit 1
  fi

  echo "download complete"
}

status() {
  local path="$1"
  if [[ -z "$path" ]]; then
    for dir in "${managed_dirs[@]}"; do
      [[ $dir == "repos" ]] && continue # remove when switch to git management for repos/
      echo "=== $dir ==="
      status "$HOME/$dir"
    done
    return
  fi

  local_canonical=$(realpath -e "$path")
  if ! is_path_managed "$local_canonical" "$HOME"; then
    exit 1
  fi

  remote_canonical=$(local_to_remote_path "$local_canonical")

  if [[ -d "$local_canonical" ]]; then
    local_canonical="$local_canonical/"
    remote_canonical="$remote_canonical/"
  fi

  upload_dry_run=$(
    rsync -ani -e "ssh -i '$sshkey' -p $port" \
      "$local_canonical" "$remote_user@$host:$remote_canonical" 2>/dev/null
  )

  download_dry_run=$(
    rsync -ani --delete -e "ssh -i '$sshkey' -p $port" \
      "$remote_user@$host:$remote_canonical" "$local_canonical" 2>/dev/null

  )

  mapfile -t local_new < <(echo "$upload_dry_run" | grep "^<f+++++++++" | awk '{print $2}')
  mapfile -t local_modified < <(echo "$upload_dry_run" | grep "^<f" | grep -v "^<f+++++++++" | awk '{print $2}')

  mapfile -t remote_new < <(echo "$download_dry_run" | grep "^>f+++++++++" | awk '{print $2}')
  mapfile -t remote_modified < <(echo "$download_dry_run" | grep "^>f" | grep -v "^>f+++++++++" | awk '{print $2}')

  conflicts=()
  for file in "${local_modified[@]}"; do
    if printf "%s\n" "${remote_modified[@]}" | grep -qx "$file"; then
      conflicts+=("$file")
    fi
  done

  if [[ ${#local_new[@]} -gt 0 || ${#local_modified[@]} -gt 0 ]]; then
    echo "Local changes:"
    [[ ${#local_new[@]} -gt 0 ]] && printf "  + %s\n" "${local_new[@]}"
    [[ ${#local_modified[@]} -gt 0 ]] && printf "  M %s\n" "${local_modified[@]}"
    echo
  fi

  if [[ ${#remote_new[@]} -gt 0 || ${#remote_modified[@]} -gt 0 ]]; then
    echo "Remote changes:"
    [[ ${#remote_new[@]} -gt 0 ]] && printf "  + %s\n" "${remote_new[@]}"
    [[ ${#remote_modified[@]} -gt 0 ]] && printf "  M %s\n" "${remote_modified[@]}"
    echo
  fi

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "Conflicts:"
    printf "  ! %s\n" "${conflicts[@]}"
  fi

  if [[ ${#local_new[@]} -eq 0 && ${#local_modified[@]} -eq 0 &&
    ${#remote_new[@]} -eq 0 && ${#remote_modified[@]} -eq 0 ]]; then
    echo "In sync"
  fi
}

list() {
  local path="$1"
  if [[ -z "$path" ]]; then
    for dir in "${managed_dirs[@]}"; do
      [[ $dir == "repos" ]] && continue # remove when switch to git management for repos/
      echo "=== $dir ==="
      list "$HOME/$dir"
    done
    return
  fi

  remote_canonical="$remote_storage_dir/$path"
  if ! is_path_managed "$remote_canonical" "$remote_storage_dir"; then
    exit 1
  fi

  ssh -i "$sshkey" -p "$port" "$remote_user@$host" "ls -lah $remote_canonical"
}

load_config # sets $host, $sshkey, $sync_dirs

parse_global_flags "$@"

subcommand="${1:-}"
shift || true

case "$subcommand" in
upload)
  upload "$@"
  ;;
download)
  download "$@"
  ;;
status)
  status "$@"
  ;;
list)
  list "$@"
  ;;
"")
  # no subcommnd, show status of all
  status
  ;;
*)
  echo "unknown command: $subcommand" >&2
  echo "run 'atlas --help' for usage" >&2
  exit 1
  ;;
esac
