#!/usr/bin/bash

repo_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")

echo "=== lint ==="

fail=0
for f in "$(dirname "$0")"/*.sh; do
  [[ $f == */lint.sh ]] && continue
  echo "=== $f ==="
  bash "$f" "$repo_root" || fail=1
done

exit $fail
