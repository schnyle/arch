# TODO

- `atlas status` reports "In sync" when Atlas is unreachable
- Pre-commit hook that generates a package list doc with descriptions from pacman -Si
- `pacman -S qbittorrent`
- fix `/tmp`

## refactor

- consider detecting if a device is already mounted
- `install_all_pacman_packages`: skip option for unavailable packages. Detect permanent failures (`pacman -Si` upfront, or parse "target not found" from stderr) and prune them from the install list with a warning, instead of retry-looping until die. Same shape would extend to `converge_unordered` for modules.
- dotfiles module: add a quiet flag to the dotfiles `install.sh` so it can run on every convergence pass without polluting logs. Would let us drop the `.dotfiles-installed` sentinel and re-stow on every pass to pick up config changes.

## virtiofs

daemon for file sharing between host and VM

`pacman -S virtiofsd`

in virt-manager:

- Memory > Enable shared memory
- Add Hardware > Filesystem
- On VM: `mkdir /mnt/new-dir` & `mount -t virtiofs arch-repo /mnt/arch-repo`
