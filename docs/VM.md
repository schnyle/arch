# Testing in a VM

Use virtualization software for quick testing.

With QEMU/virt-manager, can setup shared files with `virtiofsd`:

- Memory > Enable shared memory
- Add Hardware > Filesystem
  - Target path: arch-install
- On VM: `mkdir /arch-install` & `mount -t virtiofs arch-install /arch-install`

Run install with `bash /arch-install/bootstrap.sh --skip-clone`
