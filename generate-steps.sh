#!/bin/bash
steps_file="steps.md"
echo "" >$steps_file

mapfile -t lines < <(grep -E "^# [0-9]." install.sh)

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
  echo "$line"
  echo "$line" >>$steps_file
done
