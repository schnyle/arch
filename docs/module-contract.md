# Module contract

A **module** is a self-contained unit of system setup — a directory under `modules/install/` or `modules/post-install/` that declares the packages to install, files to place, and any imperative configuration logic.

## Directory layout

```
modules/<phase>/<name>/
  module.sh        # required — declarations + configure() function
  <config files>   # optional — referenced by configure()
```

The directory name (`<name>`) is the module's identity. The phase (`install/` or `post-install/`) determines when the driver invokes it.

## `module.sh` contract

A `module.sh` may declare any subset of:

- `pacman_packages=()` — array of packages to install during this module's phase
- `dotfiles=()` — array of `src:dest` strings (see format below)
- `configure()` — function the driver runs after packages install
- At least one of `pacman_packages` or `configure` must be present.

## `dotfiles` format

A regular array of `src:dest` strings:

```bash
dotfiles=(
  "init.lua:.config/nvim/init.lua"
  "lua/plugins.lua:.config/nvim/lua/plugins.lua"
)
```

- `src` is a path relative to the module directory.
- `dest` is a path relative to the system user's home directory.
- `:` delimiter assumes paths don't contain colons. Switch to `|` or tab if that ever bites.

## Related

- `TODO.md` — planned module conventions linter to enforce this contract automatically.
