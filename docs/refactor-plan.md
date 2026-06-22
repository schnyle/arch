# Refactor plan (scratch)

## TODO

1. ~rename bootstrap.sh to run.sh~
2. ~convert partitions, filesystems, mounts, essential-packages, and fstab install modules to a new bootstrap/bootstrap.sh. Decide organization upon writing the code. partitions/filesystems/mounts become the data-driven generic helpers (kills atlas-\* forks); this rewrite supersedes the `## Bugs to fix` below (new helpers have guards + compute `/mnt$mount`)~
3. ~remove modules/install/ and modules/post-install. all modules will now be under modules/. remove modules/\_template.~
4. ~convert hostname, localization, time, root_password, mirrors, bootloader to post-install modules (note: bootloader requires code updates — idempotency + drop chroot/`/mnt` prefixes)~
5. ~move multilib module into steam: steam installs imperatively in configure() and drops out of the declared-package bulk install (the one convention exception)~
6. create new module for snapshots disk
7. collapse orchestration: main.sh + install.sh + post-install.sh → run bootstrap, then run the module loop. probably delete converge_modules_ordered (bootstrap.sh is its own ordered script). fix validate_required_vars phase arg. get_pacman_packages still walks modules/
8. rewrite each hosts/\*.sh: drop install_modules, add partition_layout, merge moved modules into the single module list. atlas layout = desk + storage row. confirm work.sh skips bootstrap (docker host)
9. ~replace declared is_live_env with runtime detection (`[[ -d /run/archiso ]]`); add three-way entry branch (not-live → converge native; live+fresh → bootstrap; live+repair → mount_disk then converge in chroot); split bootstrap destructive/non-destructive~
10. update docs/module-contract.md
11. update modules to check any preconditions (modules requiring running commands as user should first check that the user exists) - could be a speparate todo item from this refactor

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
