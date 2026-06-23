#!/usr/bin/bash

fail=0
for f in "$(dirname "$0")"/*.sh; do
  [[ $f == */lint.sh ]] && continue
  bash "$f" || fail=1
done

exit $fail
