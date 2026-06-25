#!/usr/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "error: requires sudo" >&2
  exit 1
fi

host="$1"
module="$2"
if [[ -z $host || -z $module ]]; then
  echo "usage: $(basename "$0") <host> <module>" >&2
  exit 1
fi

repo_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")

if [[ ! -f "$repo_root/hosts/$host.sh" ]]; then
  echo "error: host not found: $host" >&2
  exit 1
fi

if [[ ! -d "$repo_root/modules/$module" ]]; then
  echo "error: module not found: $module" >&2
  exit 1
fi

if [[ ! -f "$repo_root/modules/$module/module.sh" ]]; then
  echo "error: modules/$module/module.sh not found" >&2
  exit 1
fi

source "$repo_root/lib/init.sh"

run_configure "$repo_root/modules/$module/module.sh"
