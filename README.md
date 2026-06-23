# Arch

Idempotent, modular Arch Linux installer for composing and building bespoke system.

OS bootstrapping built on top of the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

## Usage

From the Arch live environment or a booted system:

```bash
curl -fsSL https://raw.githubusercontent.com/schnyle/arch/main/install.sh | bash
```

## Architecture

The install is composed from small, reusable pieces with clear roles:

```
install.sh     # curl-piped entry point
docs/          # documentation
hooks/         # scripts run on commit
hosts/         # per-target compositions, one file per machine type
lib/           # generic primitives (logging, idempotent ops, package registry)
modules/       # system configuration logic
run/           # top-level orchestration scripts
scripts/       # useful scripts for development and commit hooks
```

**Hosts** are manifest files. They set per-machine variables, declare which modules to include, and declare additional pacman packages to install (outside of those defined in the modules).

**Modules** are recipes for getting one piece of software or one system concern into the desired state. Each module:

- Declares its packages
- Defines a single `configure()` function with the install logic
- Returns `1` if it made changes, `0` if everything was already in place

See `docs/module-contract.md` for specific details.

## Design Principles

**Idempotency** Every installation step analyzes the current system state, performs configuration steps to reach the desired state (if required), then re-verifies the system state. Re-running the installation will never cause a corrupt state.

**Convergence** The host loops over modules repeatedly until all have converged (with a per-module limit). Each pass skips satisfied state checks, attempts unsatisfied ones, and logs failures without aborting. Module ordering may affect installation time, but does not affect the ability to converge to the desired state.

**Module isolation.** A failure in one module never kills another. Modules can be run independently against a VM snapshot for development.

## Development

Setup pre-commit hooks after cloning:

```bash
git config core.hooksPath hooks
```
