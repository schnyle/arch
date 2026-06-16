#!/usr/bin/bash

storage_dir="/storage"
snapshots_dir="/snapshots"
now=$(date +"%Y%m%d-%H%M%S")
new_snapshot="$snapshots_dir/$now"
latest_snapshot="$snapshots_dir/latest"

if ! [[ -d "$storage_dir" ]]; then
  echo "ERROR: storage directory '$storage_dir' does not exist" >&2
  exit 1
fi

if ! [[ -d "$snapshots_dir" ]]; then
  echo "ERROR: snapshots directory '$snapshots_dir' does not exist" >&2
  exit 1
fi

if ! rsync -a --delete --link-dest="$latest_snapshot" "$storage_dir/" "$new_snapshot/"; then
  echo "ERROR: failed to create snapshot" >&2
  rm -rf "$new_snapshot"
  exit 1
fi

rm -f "$latest_snapshot"
ln -s "$new_snapshot" "$latest_snapshot"

echo "created new snapshot: $new_snapshot"
