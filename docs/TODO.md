# TODO

- fix `/tmp`
- helper for one-off in-place file edits like sed uncomment (multilib `[multilib]`, user `%wheel`, possibly future locale.gen and pacman.conf edits)
- module conventions linter: once the `module.sh` contract stabilizes, add a `scripts/lint-modules.sh` driven by a git pre-commit hook to catch silent failures — missing `module.sh`, modules declaring neither `pacman_packages` nor `configure`, malformed `dotfiles` entries, hosts referencing non-existent modules, unknown top-level variables in `module.sh` (catches typos by diffing the declared set against the known contract)
- runtime preflight `validate_modules_exist`: before the converge loop, scan every module a host references and `die` (collect-then-die, listing all) if any module dir is missing — fail loud instead of the silent `[[ ! -f … ]] && continue` skip that installs a passwordless/bootloader-less system. Runtime complement to the commit-time linter above; mirror `validate_required_vars`' signature so both get the same edit at flatten time.
- create generalized modules for partitions/filesystems/mounts (partitions vs atlas-partitions)
- rename `partition_layout` → `disk_layout`: it drives partition + format + mount (not just partitioning), so `disk_layout` reads more accurately. Touch all references — `hosts/*.sh`, the bootstrap helpers/loops, and `scripts/lint/partition_layout.sh` (the var and the filename).
- dedupe `storage_dirs`/`home_dirs` list between `home-dirs` and `atlas-storage-dirs` modules (currently the same set is hardcoded in both)
- extract a `render_template` helper (mktemp + sed + ensure_file_content + rm) — currently duplicated in `modules/post-install/fail2ban/module.sh` and `modules/post-install/atlas-snapshot/module.sh`
- split `modules/install/` into `stages/` (truly-ordered: partitions, filesystems, mounts, atlas-snapshot-device, essential-packages, fstab, bootloader) and migrate the rest (multilib, mirrors, time, localization, hostname, root_password) to `modules/post-install/` — drops `arch-chroot /mnt` / `/mnt` prefixes since they'd run inside the chroot, and makes the convergence-vs-linear distinction explicit in the directory layout
- explore hoisting user prompting to the front: a `pre_install()` collection pass (mirrors the existing package-aggregation pre-pass) so interactive modules ask everything up front and the convergence loop stays non-interactive/unattended/testable. Open questions: avoid shell globals (subshell isolation loses them) by storing answers as system-state (e.g. disk label) or a state file. Only worth it once >1 interactive module exists — today the lone case (snapshot device) is handled by guard+order or out-of-band labeling.
- when moving install modules to `stages/`: decide how stages validate success. The convergence pattern reused the same idempotence check for both pre-act gate and post-act verify, which broke for destructive ops like partitioning (can't distinguish "old install with right layout" from "fresh install with right layout"). Stages are currently fire-and-forget (`partitions` just runs sfdisk and trusts the exit code) — but bigger stages may need explicit assertions (e.g., post-pacstrap check that `/mnt/usr/bin/bash` exists) rather than a generic convergence-style check.
- add validate required vars to linting
- explore modules declaring preconditions (yay requires user is created)
- update modules to check any preconditions (modules requiring running commands as user should first check that the user exists)

## atlas

- `atlas status` reports "In sync" when Atlas is unreachable
- consider combining `snapshot-device` and `atlas-snapshot`
