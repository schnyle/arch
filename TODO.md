# TODO

- `atlas status` reports "In sync" when Atlas is unreachable
- Pre-commit hook that generates a package list doc with descriptions from pacman -Si
- `pacman -S qbittorrent`
- fix `/tmp`

## refactor

- consider detecting if a device is already mounted
- `install_all_pacman_packages`: skip option for unavailable packages. Detect permanent failures (`pacman -Si` upfront, or parse "target not found" from stderr) and prune them from the install list with a warning, instead of retry-looping until die. Same shape would extend to `converge_unordered` for modules.
- dotfiles module: add a quiet flag to the dotfiles `install.sh` so it can run on every convergence pass without polluting logs. Would let us drop the `.dotfiles-installed` sentinel and re-stow on every pass to pick up config changes.
- additional `ensure_*` helpers to capture repeated substate patterns across modules:
  - `ensure_symlink` (arandr, pavucontrol, minesweeper, pulseaudio)
  - `ensure_permissions` (ssh-key, user/sudoers)
  - `ensure_service_enabled` (networkmanager, virtualization, pulseaudio)
  - helper for one-off in-place file edits like sed uncomment (multilib `[multilib]`, user `%wheel`, possibly future locale.gen and pacman.conf edits)
- finalize: run `arch-chroot /mnt pacman -Sy` so the installed system's package db reflects any repo enablement (e.g., multilib) done during post-install
- run user-targeted writes as the system user (via `sudo -u` in chroot) instead of root + chown. Would make ownership correct by construction — no need for inline chowns or finalize recursive chown. Helpers could take an optional owner arg, or modules explicitly wrap in sudo -u. Trade-off: more verbose at each write site, extra arch-chroot wrapping
- extend `ensure_file_content`, `ensure_symlink`, `ensure_directory` (etc.) to take an optional owner arg. Helper would chown the target file/link AND any parent dirs it created (via mkdir -p). Eliminates the chown-parent + chown-file dance currently repeated across gtk, pulseaudio, desk-displays modules
- make path resolution context-aware so the installer can run from: the live USB install env (paths need `/mnt` prefix), the booted system as root (no prefix for system-level state), or the booted system as user (no prefix, user-scoped state only). Currently `/mnt` is hardcoded everywhere
- could make gtk module a dotfile
- module conventions linter: once the `module.sh` contract stabilizes, add a `scripts/lint-modules.sh` driven by a git pre-commit hook to catch silent failures — missing `module.sh`, modules declaring neither `pacman_packages` nor `configure`, malformed `dotfiles` entries, hosts referencing non-existent modules, unknown top-level variables in `module.sh` (catches typos by diffing the declared set against the known contract)

## virtiofs

daemon for file sharing between host and VM

`pacman -S virtiofsd`

in virt-manager:

- Memory > Enable shared memory
- Add Hardware > Filesystem
  - Target path: arch-install
- On VM: `mkdir /arch-install` & `mount -t virtiofs arch-install /arch-install`
