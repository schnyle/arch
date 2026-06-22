# Module contract

A **module** is a self-contained unit of system setup — a directory under `modules/` that declares the packages to install, files to place, and any imperative configuration logic.

## Directory layout

```
modules/<name>/
  module.sh        # required — declarations + configure() function
  <config files>   # optional — referenced by configure()
```

The directory name (`<name>`) is the module's identity. Since all modules live at the same directory level, there can be no duplicate module names.

## `module.sh` contract

A `module.sh` may declare:

- `pacman_packages=()` — array of pacman packages to install
- `configure()` — function the driver runs after packages install

At least one of `pacman_packages` or `configure` must be present.

## `lib/modules.sh`

The `lib/modules.sh` provides a family of idempotent helper functions for regular configuration logic a module may desire. Prefer using these over writing new logic.
