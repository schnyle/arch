# Arch

Idempotent, modular Arch Linux installer for composing and building bespoke system.

OS bootstrapping built on top of the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

## Architecture

The install is composed from small, reusable pieces with clear roles:

```
bootstrap.sh   # curl-piped entry point: clone repo, prompt for host, exec
lib/           # generic primitives (logging, idempotent ops, package registry)
modules/       # software-specific install/configure logic
hosts/         # per-target compositions, one file per machine type
assets/        # static files copied during install
```

**Hosts** are manifest files. They set per-machine variables, declare which modules to include, and run them in three phases.

**Modules** are recipes for getting one piece of software or one system concern into the desired state. Each module:

- Declares its packages at the top (side-effect-free)
- Defines a single `configure_<name>` function with the install logic
- Returns `1` if it made changes, `0` if everything was already in place

**Lib** is the generic foundation — operations that know nothing about specific software. Modules call into lib; lib never depends on modules.

## Design Principles

**Idempotent by default** Every step checks the desired state, acts only if not met, then verifies. The check and the verification are the same test. A re-run with no state drift is a no-op.

**Convergence** The host loops over modules repeatedly. Each pass skips satisfied checks, attempts unsatisfied ones, and logs failures without aborting. The loop exits when every module reports a satisfied. Module ordering doesn't need to be declared — dependencies resolve naturally across passes.

**Module isolation.** A failure in one module never kills another. Modules can be run independently against a VM snapshot for development. `die` is reserved for failures that are unrecoverable within a single module, not for aborting the whole install.

## Host Phases

A host script runs three phases:

1. **Install modules** — sequential (run via `converge_ordered`). Maps to sections 1-3 of the Arch installation guide: disk setup, pacstrap, fstab, locale, bootloader, etc.
2. **Post-install modules** — convergence loop (run via `converge_unordered`). Maps to the Arch guide's post-installation: user environment, packages, services, dotfiles.
3. **Cleanup modules** — sequential, runs after the convergence loop stabilizes (e.g. removing temporary install scaffolding).

## Naming Conventions

- Directory and file names: kebab-case (`desktop-i3.sh`)
- Function names: snake_case (`configure_desktop_i3`)
- Variables: snake_case (uppercase reserved for environment variables)
- Module function name = filename with `configure_` prefix and hyphens converted to underscores

## Module Templates

**Single-state module** — one idempotent state to converge:

```bash
: "${var1:=}"

my_module_pacman_packages=(
  pkg-a   # what it does
  pkg-b   # what it does
)
add_pacman_packages "${my_module_pacman_packages[@]}"

# module-local helpers

my_module_done() {
  # idempotent check that returns 0 if state is correct
}

configure_my_module() {
  require_var var1

  my_module_done && return 0

  log "doing work"
  # the action

  return 1   # convergence pattern: retry verifies via re-check above
}
```

**Multi-state module** — several independent substates with per-substate idempotency:

```bash
: "${var1:=}"
: "${var2:=}"

my_module_pacman_packages=(
  pkg-a   # what it does
  pkg-b   # what it does
)
add_pacman_packages "${my_module_pacman_packages[@]}"

# module-local constants/helpers

configure_my_module() {
  require_var var1 var2

  local changed=0

  if ! check_substate_a; then
    log "configuring substate a"
    # action
    changed=1
  fi

  if ! check_substate_b; then
    log "configuring substate b"
    # action
    changed=1
  fi

  return $changed
}
```

Both return nonzero when the module did work, so the orchestrator (`converge_ordered` or `converge_unordered`) re-verifies on the next (silent) pass. Return 0 means fully converged.

Packages declared in `<module>_pacman_packages` are registered at source time and installed in a single batched `pacman -S --needed` call before the convergence loop runs. The named-array convention makes the full package list extractable by external scripts.

## Development

Setup pre-commit hooks after cloning:

```bash
git config core.hooksPath hooks
```

See `docs/refactor-plan.md` for the full architecture details and
porting notes from the original monolithic install scripts.

## Requirements

- UEFI system
- Internet connection
- At least 4GB RAM
- 20GB+ disk space
