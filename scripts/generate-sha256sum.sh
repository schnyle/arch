#!/bin/bash

if [[ -z "$1" ]]; then
  echo "provide an inupt directory"
  exit 1
fi

input_dir=$(realpath "$1")
install_script="$input_dir/install.sh"
checksum="$input_dir/install.sh.sha256"

if [[ ! -f "$install_script" ]]; then
  echo "no install.sh found in $input_dir"
  exit 1
fi

echo "generating checksum for $input_dir"
sha256sum "$install_script" >"$checksum"
git add "$checksum"
