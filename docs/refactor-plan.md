# Refactor plan (scratch)

## TODO

1. rename bootstrap.sh to run.sh
2. convert partitions, filesystems, mounts, essential-packages, fstab, and bootloader install modules to a new bootstrap/bootstrap.sh. Decide organization upon writing the code. partitions/filesystems/mounts become the data-driven generic helpers (kills atlas-\* forks); this rewrite supersedes the `## Bugs to fix` below (new helpers have guards + compute `/mnt$mount`)
3. remove modules/install/ and modules/post-install. all modules will now be under modules/. remove modules/\_template.
4. convert hostname, localization, time, root_password, mirrors, to post-install modules
5. move multilib module into steam: steam installs imperatively in configure() and drops out of the declared-package bulk install (the one convention exception)
6. create new module for snapshots disk
7. collapse orchestration: main.sh + install.sh + post-install.sh → run bootstrap, then run the module loop. probably delete converge_modules_ordered (bootstrap.sh is its own ordered script). fix validate_required_vars phase arg. get_pacman_packages still walks modules/
8. rewrite each hosts/\*.sh: drop install_modules, add partition_layout, merge moved modules into the single module list. atlas layout = desk + storage row. confirm work.sh skips bootstrap (docker host)
9. replace declared is_live_env with runtime detection (`[[ -d /run/archiso ]]`); add three-way entry branch (not-live → converge native; live+fresh → bootstrap; live+repair → mount_disk then converge in chroot); split bootstrap destructive/non-destructive
10. update docs/module-contract.md
11. update modules to check any preconditions (modules requiring running commands as user should first check that the user exists) - could be a speparate todo item from this refactor

## Phases

- **bootstrap**: ordered, run-once, live-env, fail-fast. Separate process,
  not part of the convergent loop.
- **modules**: convergent, idempotent, looped. (was: post-install. install
  modules go away — everything left is just a "module".)

Principle: a thing lives in bootstrap only if it _must_ (ordered, run-once,
can't converge). Everything else is a convergent module. Strong default = module.

## install modules → bootstrap (ordered)

partitions, filesystems, mounts, essential-packages, fstab, bootloader.
order: partition → format → mount → pacstrap → fstab → bootloader.

## install modules → modules (convergent)

hostname, localization, time, root_password, mirrors — drop `/mnt` + `arch-chroot`.
(mirrors only sets up reflector.timer; doesn't gate install.)
multilib: folded into steam module (steam-only; enable + install imperatively).

## Entrypoint

- `bootstrap.sh` → renamed `run.sh` (the curl-and-clone seed). Frees
  "bootstrap" for the phase above.

## Entry / live-env detection

- Detect at runtime with `[[ -d /run/archiso ]]`; delete declared `is_live_env`
  (it's wrong-by-construction on the installed system → accidental wipe).
- Not live (booted / docker) → converge loop, native, no chroot.
- Live + fresh → bootstrap (destructive) → converge in `arch-chroot /mnt`.
- Live + repair → run only non-destructive prefix (`mount_disk`) → converge in
  chroot. Prompt at entry: bootstrap (wipes) vs converge existing.
- Split bootstrap into destructive (partition/format/pacstrap) vs
  non-destructive (mount) so the prefix is callable alone.
- Modules stay chroot-agnostic; only the driver wraps `arch-chroot`.

## Layout data

- Ordered indexed array of `:`-delimited records; order = partition number.
- Not assoc array (no insertion order), not JSON (jq dep, overkill).
- Schema `size:gpt-type:fstype:label:mount`
  - size "" = rest of disk
  - gpt-type = sgdisk shortcode (ef00/8200/8300)
  - mount "swap" = swap area, "" = unmounted; paths are target-relative
- One table (per host) drives partition + format + mount + all 3 guards.
  Host = data only; bootstrap logic is host-agnostic. Kills atlas-\* forks.
- Tools: write partitions with `sgdisk` (per-partition loop, ergonomic);
  verify with `sfdisk -d` (ordered type-GUID compare). One glue map
  shortcode→GUID bridges the two.
- Filesystems: `case` not flat map — label flag differs (fat `-n`, ext4/swap
  `-L`). Guard needs fstype→blkid map (fat32 reports as `vfat`).
- Mounts: `swapon` for swap, `mount --mkdir` for rest under `/mnt$mount`.
  Sort by mountpoint depth (shortest first) so parent mounts before child
  (`/` before `/boot`) — can't use array order (root is listed last).
  `/mnt$mount` derivation fixes the atlas `/mnt/mnt/storage` bug.

## Code to review (draft)

```bash
# --- hosts/desk.sh : data only ---
# fields: size : gpt-type : fstype : fs-label : mount
#   size ""      = rest of disk
#   mount "swap" = swap area, "" = unmounted
partition_layout=(
  "$boot_size:ef00:fat32::/boot"
  "$swap_size:8200:swap::swap"
  ":8300:ext4::/"
)

# --- lib/bootstrap.sh : logic, host-agnostic ---
gpt_type_guid() {
  case $1 in
    ef00) echo C12A7328-F81F-11D2-BA4B-00A0C93EC93B ;;  # EFI
    8200) echo 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F ;;  # swap
    8300) echo 0FC63DAF-8483-4772-8E79-3D69D8477DE4 ;;  # Linux
    *)    die "unknown gpt type: $1" ;;
  esac
}

# pre-check == verify: ordered list of expected type GUIDs vs actual
partitions_correct() {
  local device=$1 p
  local -a want actual
  for p in "${partition_layout[@]}"; do
    want+=("$(gpt_type_guid "$(cut -d: -f2 <<<"$p")")")
  done
  mapfile -t actual < <(sfdisk -d "$device" 2>/dev/null | grep -oiP 'type=\K[0-9A-F-]+')
  [[ "${want[*]}" == "${actual[*]}" ]]   # also enforces exact count
}

partition_disk() {
  local device=$1
  partitions_correct "$device" && return 0

  log "partitioning $device"
  sgdisk --zap-all "$device"
  local n=1 size type
  for p in "${partition_layout[@]}"; do
    IFS=: read -r size type _ <<<"$p"          # _ = fstype:label:mount, used later
    sgdisk -n "${n}:0:${size:+"+$size"}" -t "${n}:${type}" "$device"
    n=$((n+1))
  done
  partprobe "$device"
  return 1
}

# fat32's label flag is -n; ext4/swap use -L
make_filesystem() {
  local dev=$1 fstype=$2 label=$3
  case $fstype in
    fat32) mkfs.fat -F32 ${label:+-n "$label"} "$dev" ;;
    ext4)  mkfs.ext4    ${label:+-L "$label"} "$dev" ;;
    swap)  mkswap       ${label:+-L "$label"} "$dev" ;;
    *)     die "unknown fstype: $fstype" ;;
  esac
}

# guard needs a second tiny map: blkid reports fat32 as "vfat"
blkid_type() { case $1 in fat32) echo vfat ;; *) echo "$1" ;; esac; }

format_disk() {
  local device=$1 prefix n=1 size type fstype label mount
  prefix=$(partition_prefix "$device")
  for p in "${partition_layout[@]}"; do
    IFS=: read -r size type fstype label mount <<<"$p"
    local dev="${prefix}${n}"; n=$((n+1))
    [[ $(blkid -o value -s TYPE "$dev" 2>/dev/null) == "$(blkid_type "$fstype")" ]] && continue
    log "formatting $dev ($fstype)"
    make_filesystem "$dev" "$fstype" "$label"
  done
}

mount_disk() {
  local device=$1 prefix n=1 size type fstype label mount
  prefix=$(partition_prefix "$device")
  local -a fs_mounts swaps

  for p in "${partition_layout[@]}"; do
    IFS=: read -r size type fstype label mount <<<"$p"
    local dev="${prefix}${n}"; n=$((n+1))
    if [[ $mount == swap ]]; then swaps+=("$dev")
    elif [[ -n $mount ]]; then fs_mounts+=("$mount $dev"); fi
  done

  # shortest path first → parent before child (/ before /boot)
  while read -r mnt dev; do
    findmnt -no SOURCE "/mnt$mnt" &>/dev/null && continue
    log "mounting $dev at /mnt$mnt"
    mount --mkdir "$dev" "/mnt$mnt"
  done < <(printf '%s\n' "${fs_mounts[@]}" | awk '{print length($1), $0}' | sort -n | cut -d' ' -f2-)

  local s
  for s in "${swaps[@]}"; do
    swapon --show=NAME --noheadings | grep -qx "$s" && continue
    log "enabling swap $s"; swapon "$s"
  done
}
```

## /snapshots

- Separate physical disk by design (survives reinstall/root-disk failure),
  so it can't live in `partition_layout` (that's one disk). NOT a partition.
- Make it a convergent module (`atlas-snapshot`). Steps, all guarded:
  format-if-needed → mount-if-needed → fstab-entry-if-needed.
- Runs in chroot → paths are `/snapshots`, `genfstab -U /`.
- fstab: don't re-run plain genfstab (dups every mount). Filter to the one
  line and guard:
  `grep -q " /snapshots " /etc/fstab || genfstab -U / | grep " /snapshots " >> /etc/fstab`
- Find disk by FS label (`blkid -L snapshots`), not interactive-every-time.
- First-run identification (blank disk has no label yet) is the one prompt;
  handle via guard+order or out-of-band labeling. See TODO (hoist prompting).
- Rejected: a `preserve` field on partition records to keep data on wipe.
  Doesn't solve this (separate disk anyway); forces surgical per-partition
  partitioning instead of whole-table `--zap-all`; conflates idempotency
  with data-safety. Defer until a same-disk keep-across-reinstall need (e.g.
  `storage`) actually exists.

## Ordering

- No `depends`, no `priority`. List order already is soft priority.
- Modules check preconditions first, bail cheap → free retries.

## Bugs to fix

- partitions/mounts never call guards → destructive re-run.
- atlas-mounts: mounts `/mnt/mnt/storage`, checks `/mnt/storage`.
