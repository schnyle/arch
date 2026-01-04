#!/bin/bash

if [[ -z "$1" ]]; then
  echo "provide an inupt directory"
  exit 1
fi

input_dir=$(realpath "$1")
install_script="$input_dir/install.sh"
checksum="$input_dir/install.sh.sha256"

if git diff --cached --name-only | grep -q "^${install_script}$"; then
  echo "detected changes to $install_script, generating checksum"
  sha256sum "$install_script" >"$checksum"
  git add "$checksum"
fi
