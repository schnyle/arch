# CLAUDE.md

Project context for Claude Code. This file describes the architecture of this
Arch install repo. Read it in full before making changes.

## What This Repo Is

A set of composable Arch Linux install scripts targeting multiple machine
types. Currently in the middle of a refactor away from a single monolithic
`install.sh` toward a modular layout. The refactor is happening on this
branch; `main` still has the monolith for reference.

Target machine types (each gets its own host file):

- `personal` — workstation with i3, dev tooling, GPU, gaming
- `atlas` — home server, headless, with WireGuard/firewall/backup
- `rpi-tv` — Raspberry Pi running as a kiosk-mode "dumb TV"

The same modules get reused across hosts where they apply. The personal
build and atlas share base-system, users, networking, ssh; only personal
adds desktop and dev tooling; only atlas adds firewall and wireguard.

## Directory Layout

```
.
├── bootstrap.sh                 # curl-piped entry point
├── lib/                         # generic helpers; depend on nothing else
├── modules/                     # software-specific install/configure logic
├── hosts/                       # per-target compositions
├── assets/                      # static files copied during install
└── docs/                        # design docs and debugging notes
```

The split between `lib/` and `modules/` matters and is described in detail
below.

## Naming Conventions

- Directory and file names: kebab-case (`desktop-i3.sh`, `ssh-harden.sh`)
- Function names: snake_case (`configure_desktop_i3`, `ensure_service_enabled`)
- Variables: snake_case for all script variables. Uppercase is reserved
  for environment variables and shell builtins.
- The function name for a module matches its filename with `configure_`
  prefix and hyphens converted to underscores:
  `modules/desktop-i3.sh` defines `configure_desktop_i3`.

## Lib vs Modules

The split is strict and load-bearing for the architecture. Get it right.

**`lib/`** is generic primitives. Files here know about *operations*, not
*software*. No specific package names, no specific config file paths from
this setup, no specific services. Lib functions should be useful in any
other Arch install project unchanged.

**`modules/`** is specific recipes. Files here know about *software*. They
name packages, point at config files, enable specific services.

Dependency direction: modules depend on lib. Lib never depends on modules.

The test for where new code goes: "would another Arch project find this
useful as-is?" If yes, it belongs in lib. If it only makes sense because
we specifically want i3 with alacritty and qutebrowser, it belongs in a
module.

Examples of the split:

```bash
# lib/idempotent.sh — generic, works for any service
ensure_service_enabled() {
  local service=$1
  systemctl is-enabled "$service" &>/dev/null && return
  systemctl enable "$service"
}

# modules/networking.sh — specific, knows we use NetworkManager
add_pacman networkmanager
configure_networking() {
  ensure_service_enabled NetworkManager
}
```

Rules of thumb that fall out:

- Lib functions are verbs. Module functions are nouns plus configuration.
- Lib never calls `add_pacman`. Adding packages is a software-specific
  declaration; that's module territory.
- Modules don't directly call `systemctl`, `cp`, `ln`, etc. They go through
  lib helpers (`ensure_service_enabled`, `ensure_file_contents`,
  `ensure_symlink`). The module says *what* state should exist; lib knows
  *how* to achieve it.
- Modules don't define generic-looking helpers. If you find yourself doing
  this, lift the helper into lib.

## Library Files

Suggested initial split (create as needed, not all up front):

- `lib/common.sh` — `log()`, `die()`, `prompt()`, `confirm()`, `restart_now()`.
  The dependency floor for everything else.
- `lib/detect.sh` — `is_vm()`, `has_nvidia()`, `is_uefi()`, hardware/env
  introspection. Return exit codes for use in `if has_nvidia; then ...`.
- `lib/packages.sh` — package registry (see "Package Aggregation" below).
- `lib/idempotent.sh` — `ensure_service_enabled`, `ensure_file_contents`,
  `ensure_symlink`, `ensure_user_in_group`, etc.
- `lib/disk.sh` — partition table operations, format, mount, wipefs.
- `lib/chroot.sh` — `arch-chroot` wrappers including efivars bind-mount.
- `lib/nvram.sh` — efibootmgr operations including orphan cleanup.

## Module Conventions

Every module file has the same shape:

1. **Package declarations at top** using `add_pacman` / `add_aur` /
   `add_vscode`. No conditionals — if a module is included in a host, all
   its packages get installed.
2. **Required globals declared** using `: "${var:=}"` no-op stub
   assignments, one per global the module reads. This documents the
   module's input contract, silences shellcheck SC2154
   (referenced-but-not-assigned), and preserves typo detection within
   the module body.
3. **A single `configure_<name>` function** with the install/configure logic.
   No pacman calls in here (packages already installed by orchestrator).
   First line should be `require_var var1 var2 ...` matching the stub
   list — fails loudly at runtime if the host didn't set a value (catches
   both unset and empty).
4. **Helper functions are file-local**, used only by the module's own
   configure function. If a helper would be useful to another module, it
   belongs in lib instead.

Example:

```bash
# modules/desktop-i3.sh

: "${system_user:=}"

add_pacman \
  i3-wm i3blocks i3lock i3status \
  alacritty arandr xclip \
  picom

configure_desktop_i3() {
  require_var system_user
  log "configuring i3 desktop"

  ensure_directory "/home/$system_user/.config"
  ensure_file_contents "/home/$system_user/.config/i3/config" "$i3_config"
  ensure_user_service_enabled pulseaudio.service
}
```

The stub declarations and `require_var` argument list are the same
contract written twice — keep them in sync. When you add or rename a
global, update both lines.

Key discipline: **sourcing a module is side-effect-free** except for
package declarations and stub declarations (the latter only assign empty
when the global is unset). Configuration only runs when the function is
called explicitly. This lets hosts decide order, support dry-run, and
source all modules to build the full package list without doing any
actual install.

## Host Conventions

Hosts are short manifest files. They:

1. Set per-machine variables (hostname, system_user, hardware UUIDs, etc.)
2. Declare a list of modules to include
3. Apply conditional additions (e.g., `has_nvidia && MODULES+=(nvidia)`)
4. Support inspection flags (`--list-packages`, `--dry-run`)
5. Run package install (once, batched) then run all configure functions

Example shape:

```bash
#!/bin/bash
# hosts/personal.sh
set -euo pipefail

# Per-machine config
SYSTEM_USER="kyle"
HOSTNAME="arch-personal"
TIME_ZONE="/usr/share/zoneinfo/America/Denver"
MAIN_SYSTEM_UUID="0218a900-edb8-11ee-9a60-aaa17ee25e02"

# Resolve repo root and load lib
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
for f in lib/*.sh; do source "$f"; done

# Module list
MODULES=(
  base-system
  bootloader
  users
  networking
  shell
  audio
  desktop-i3
  fonts
  dev-tooling
  browser
  dotfiles
)

# Hardware-conditional
has_nvidia && MODULES+=(nvidia)
is_vm     || MODULES+=(virtualization)

# Source all modules (registers packages)
for m in "${MODULES[@]}"; do
  source "modules/$m.sh"
done

# Inspection flags
case "${1:-}" in
  --list-packages)
    printf '%s\n' "${PACMAN_PACKAGES[@]}" | sort -u
    exit 0
    ;;
  --dry-run)
    log "would install: ${PACMAN_PACKAGES[*]}"
    log "would run: ${MODULES[*]}"
    exit 0
    ;;
esac

# Execute
install_all_pacman
install_all_aur

for m in "${MODULES[@]}"; do
  fn="configure_${m//-/_}"
  log "==> $fn"
  "$fn"
done
```

Reading a host file should tell you everything about what gets installed
on that machine: per-machine config at the top, list of modules in the
middle, no hidden behavior. This is the "table of contents" view that
makes the whole architecture comprehensible.

## Bootstrap

`bootstrap.sh` is the entry point. Keep it small. Responsibilities:

1. Ensure git is available (install if missing).
2. Clone the repo to a known temp directory (clean, no stale state).
3. Prompt for which host to run (or read from `$HOST` env var for
   non-interactive use).
4. `exec` the chosen host script.

Distribution model:

```
curl -L https://raw.githubusercontent.com/schnyle/arch/main/bootstrap.sh | bash
```

Non-interactive variant:

```
HOST=personal curl -L .../bootstrap.sh | bash
```

## Package Aggregation

One of the goals of the refactor is to make pacman calls batched rather
than per-module. Modules declare packages; hosts install them all at once.

The registry lives in `lib/packages.sh`:

```bash
PACMAN_PACKAGES=()
AUR_PACKAGES=()
VSCODE_EXTENSIONS=()

add_pacman()  { PACMAN_PACKAGES+=("$@"); }
add_aur()     { AUR_PACKAGES+=("$@"); }
add_vscode()  { VSCODE_EXTENSIONS+=("$@"); }

install_all_pacman() {
  [[ ${#PACMAN_PACKAGES[@]} -eq 0 ]] && return
  log "installing ${#PACMAN_PACKAGES[@]} pacman packages"
  pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" \
    || die "pacman install failed"
}

install_all_aur() {
  [[ ${#AUR_PACKAGES[@]} -eq 0 ]] && return
  sudo -u "$SYSTEM_USER" yay -S --needed --noconfirm "${AUR_PACKAGES[@]}" \
    || die "yay install failed"
}
```

Benefits this delivers:

- Single pacman call resolves dependencies once, hits mirrors once, runs
  hooks once. On a fresh install this is the difference between seconds
  and minutes.
- `--list-packages` flag on hosts becomes trivial — just dump the
  aggregated array.
- Cross-host diffing is trivial: `diff <(personal.sh --list-packages)
  <(atlas.sh --list-packages)`.
- `--needed` makes the install idempotent on re-runs.

## Idempotency Pattern

Every step in a configure function should be idempotent: safe to run
multiple times, no-op when already done. The lib provides helpers; modules
use them.

The discipline: **check the actual artifact a step creates, not a proxy.**

- Check that a service is enabled by `systemctl is-enabled`, not by
  inferring from package presence.
- Check that a file has the right contents by reading it, not by checking
  a timestamp.
- Check that a bootloader is installed by looking for the `.efi` file on
  the target disk, not by querying firmware state.

If a step creates multiple artifacts, check the most diagnostic one
(usually the last thing the step writes).

## Error Handling

Critical commands must fail loud. The old monolith's biggest footgun was
silent failure: `pacman -S`, `grub-install`, and `grub-mkconfig` were
called without exit-code checking, so failures cascaded into
"installation completed but the system doesn't boot" symptoms.

Two compatible options:

1. **`set -euo pipefail`** at the top of host scripts. Will require
   flipping idempotent-check patterns that intentionally let commands
   fail (`pacman -Q` probes, `grep -q`) to explicit `if ! cmd; then ...`.
   More refactor, more rigor.
2. **Wrap load-bearing commands with `|| die "ERROR: <context>"`** —
   especially `pacstrap`, `pacman -S`, `grub-install`, `grub-mkconfig`,
   `arch-chroot ... critical_command`. Lighter touch.

Either way: exit loudly on first failure rather than drift to a broken
state that subsequent passes can't detect. This is the right default for
a restart-until-converged installer.

## State Surfaces

The installer operates on multiple distinct state surfaces. Bugs hide at
the boundaries. Name functions and variables to make clear which surface
they operate on.

- **Live USB environment** — where the script initially runs. `/` here.
- **Chroot environment** — accessed via `arch-chroot /mnt`. Same paths
  without the `/mnt` prefix.
- **Target disk** — partitions, filesystems, files on the installed system.
- **NVRAM** — firmware state on the motherboard, persists across drives.

Confusing these surfaces was the root cause of the bootloader bug the
project hit on `main`. See `docs/uefi-arch-install-notes.md` for the
full debugging writeup if context on that is useful.

## Suggested First Steps

To avoid getting stuck in design, build a vertical slice end-to-end before
going wide:

1. `bootstrap.sh` — minimum viable: clone, prompt, exec.
2. `lib/common.sh` and `lib/packages.sh` — minimum viable library.
3. `hosts/personal.sh` with just `modules/base-system.sh`.
4. Get this to run start-to-finish on a VM, producing a bootable Arch
   with just the base system installed.
5. Add modules one at a time after that: bootloader, users, networking,
   shell, etc. Bring content over from the old monolith incrementally.

Don't try to bring everything over at once. Build the pipeline with one
module before there are five interacting ones — debugging the
architecture itself is much easier when there's a working baseline.

## Reference: The Old Monolith

`install.sh` on `main` contains the current working installer. It's a
single 944-line bash file with the structure:

- Sections 0-1: setup, partition disks, format, mount
- Section 2: pacstrap base system, configure mirrors
- Section 3: system config (locale, time, hostname, bootloader)
- Section 5: post-install (users, packages, dotfiles, services)

When porting logic over, the structure roughly maps:

- Section 1.9 → `modules/base-system.sh` + `lib/disk.sh`
- Section 2 → `modules/base-system.sh`
- Section 3.3-3.5 → `modules/base-system.sh` (locale, time, hostname)
- Section 3.8 → `modules/bootloader.sh` (with the fixes from
  `docs/uefi-arch-install-notes.md`)
- Section 5.1.1 → `modules/users.sh`
- Section 5.2 → split across module-specific files
- Section 5.3 → split across module-specific files

The old script has known issues (silent command failures, the NVRAM proxy
bug in 3.8) that the refactor should address rather than carry forward.
