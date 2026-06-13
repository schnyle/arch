# Module contract

> Draft — fields and constraints reflect the design decision but the
> driver behavior section has TBDs. Revisit after the `module.sh`
> migration is complete.

A module is a self-contained unit of system setup — a directory under
`modules/install/` or `modules/post-install/` that declares the packages
to install, the dotfiles to place, and any imperative configuration
logic.

## Directory layout

```
modules/<phase>/<name>/
  module.sh        # required — declarations + configure() function
  <config files>   # optional — referenced by dotfiles entries
  <helpers/>       # optional — extra logic sourced by configure()
```

The directory name (`<name>`) is the module's identity. The phase
(`install/` or `post-install/`) determines when the driver invokes it.

## `module.sh` contract

A `module.sh` may declare any subset of:

- `pacman_packages=()` — array of packages to install during this module's phase
- `dotfiles=()` — array of `src:dest` strings (see format below)
- `configure()` — function the driver runs after packages install

**At least one of `pacman_packages` or `configure` must be present.** A
module with only `dotfiles` has nothing to install and nothing to do
beyond placing files; that placement belongs inside a `configure` step
or driver-side `apply_dotfiles` pass.

## `dotfiles` format

A regular array of `src:dest` strings:

```bash
dotfiles=(
  "init.lua:.config/nvim/init.lua"
  "lua/plugins.lua:.config/nvim/lua/plugins.lua"
)
```

- `src` is a path relative to the module directory.
- `dest` is a path relative to the user's home (`$HOME`).
- `:` delimiter assumes paths don't contain colons. Switch to `|` or
  tab if that ever bites.

If a third per-entry field (mode, owner, conditional) ever becomes
useful, revisit — flat delimited strings get cramped past two fields.

## Driver behavior

- `pacman_packages` — collected from every selected module into a
  deduplicated batch, installed once per phase.
- `dotfiles` — placed via `ensure_file_content` (resolving `src`
  against the module directory). TBD whether the driver applies these
  automatically or `configure` calls an `apply_dotfiles` helper.
- `configure` — invoked once per convergence pass.

The driver sources `module.sh` in a subshell so module-level state
(`pacman_packages`, `dotfiles`, `configure`) can't leak between
modules.

## Related

- `CLAUDE.md` — design principles (idempotency, convergence, module isolation).
- `TODO.md` — planned module conventions linter to enforce this contract automatically.
