# TODO

- `atlas status` reports "In sync" when Atlas is unreachable
- Pre-commit hook that generates a package list doc with descriptions from pacman -Si
- `pacman -S qbittorrent`
- fix `/tmp`

## virtiofs

daemon for file sharing between host and VM

`pacman -S virtiofsd`

in virt-manager:

- Memory > Enable shared memory
- Add Hardware > Filesystem
- On VM: `mkdir /mnt/new-dir` & `mount -t virtiofs arch-repo /mnt/arch-repo`
