#!/bin/bash

if [[ -z "$1" ]]; then
  echo "provide an input directory"
  exit 1
fi

input_dir=$(realpath "$1")

install_script="$input_dir/install.sh"
if [[ ! -f "$install_script" ]]; then
  echo "no install.sh found in $input_dir"
  exit 1
fi

procedure="$input_dir/procedure.md"

if ! git diff --cached --name-only | grep -q "^${install_script}$"; then
  exit 0
fi

echo "detected changes to $install_script, generating procedure"

echo "" >"$procedure"

mapfile -t lines < <(grep -E "^# [0-9]." "$install_script")

for header in "${lines[@]}"; do
  # check if '# N. ' - top level header
  if [[ "$header" =~ ^#\ [0-9]+\.\ [^0-9] ]]; then
    prefix=""
  else
    number=$(echo "$header" | grep -oE "[0-9]+(\.[0-9]+)*")
    depth=$(echo "$number" | tr -cd '.' | wc -c)
    depth=$((depth + 1))
    prefix=$(printf '\t%.0s' $(seq 1 $((depth - 1))))
  fi

  header="${header#'# '}"
  line="${prefix}${header}"
  echo "$line" >>"$procedure"
done

git add "$procedure"
