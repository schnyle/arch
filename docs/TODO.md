# TODO

- `atlas status` reports "In sync" when Atlas is unreachable
- fix `/tmp`
- helper for one-off in-place file edits like sed uncomment (multilib `[multilib]`, user `%wheel`, possibly future locale.gen and pacman.conf edits)
- finalize: run `arch-chroot /mnt pacman -Sy` so the installed system's package db reflects any repo enablement (e.g., multilib) done during post-install
- module conventions linter: once the `module.sh` contract stabilizes, add a `scripts/lint-modules.sh` driven by a git pre-commit hook to catch silent failures — missing `module.sh`, modules declaring neither `pacman_packages` nor `configure`, malformed `dotfiles` entries, hosts referencing non-existent modules, unknown top-level variables in `module.sh` (catches typos by diffing the declared set against the known contract)

## virtiofs

daemon for file sharing between host and VM

`pacman -S virtiofsd`

in virt-manager:

- Memory > Enable shared memory
- Add Hardware > Filesystem
  - Target path: arch-install
- On VM: `mkdir /arch-install` & `mount -t virtiofs arch-install /arch-install`
