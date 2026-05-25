# UEFI, GRUB, and the Arch Install Script — Debugging Notes

Reference document from the debugging session where a fresh Arch install on
nvme dropped to BIOS instead of booting. Captures the root cause, the UEFI
concepts needed to reason about it, and the patterns worth carrying into the
script refactor.

## TL;DR

The script's check for "is GRUB installed" asked the wrong question. It looked
in NVRAM for any entry mentioning `grubx64.efi`, which got false-positive hits
from stale entries left over from the wiped sda/sdb installs. That made
`grub-install`, `grub-mkconfig`, and the fallback `BOOTX64.EFI` copy all get
skipped silently. The fix is to check the install target's disk for the
bootloader file directly, and to clean up orphaned NVRAM entries
unconditionally.

## UEFI Boot, From First Principles

### NVRAM vs NVMe

These are unrelated despite the similar names.

**NVMe** is a protocol (Non-Volatile Memory **express**) for talking to fast
PCIe-attached SSDs. `/dev/nvme0n1` is a physical M.2 stick holding a terabyte
of storage.

**NVRAM** is a small (typically under 1MB) chip on the motherboard, part of
the UEFI firmware. It retains data across power cycles and stores firmware
settings: fan curves, secure boot keys, boot order, and a list of *boot
entries*. Has nothing to do with the SSD.

Both contain "non-volatile" because both retain data without power. That's
the only thing they share.

### UEFI Firmware vs `.efi` Files

Two distinct things both called "EFI" depending on context.

**UEFI (or EFI) the firmware** is what runs from the motherboard's flash chip
when the machine powers on. It's the modern replacement for BIOS — the
low-level code that initializes hardware, presents the setup screen, and
decides what to boot.

**A `.efi` file** is an executable that runs *inside* the UEFI environment.
UEFI exposes an API; `.efi` files are programs written against that API.

The file format is PE32+, the same as Windows `.exe`. Historical accident:
Intel and Microsoft developed the spec together and reused the existing
executable format.

A `.efi` file is a *format*, not a category of program. Bootloaders happen to
be packaged as `.efi` files on UEFI systems, but plenty of other things are
too: Memtest86, the UEFI Shell, vendor firmware updaters, network boot
clients, pre-boot security tools. Every UEFI bootloader is a `.efi` file; not
every `.efi` file is a bootloader.

Bootloaders like GRUB are *compiled to* EFI format. The source is C (and
assembly). When you run `grub-install --target=x86_64-efi`, GRUB gets compiled
and packaged as `grubx64.efi`. The same GRUB source compiled with
`--target=i386-pc` produces raw machine code for legacy BIOS boot, which
doesn't involve `.efi` files at all.

### The EFI System Partition (ESP)

The ESP is the partition the firmware reads bootloader binaries from. Three
properties define an ESP:

1. **FAT32 filesystem.** UEFI spec requires it. Firmware has a FAT driver in
   ROM but no driver for ext4/btrfs/xfs. The partition holding bootloader
   binaries has to be readable by firmware natively.
2. **GPT partition type GUID** `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`. In the
   sfdisk heredoc, the `U` shorthand sets this. It's how firmware identifies
   the partition as "the boot one" without scanning every partition on every
   disk.
3. **The `\EFI\` directory at its root**, containing subdirectories per
   bootloader vendor: `\EFI\GRUB\grubx64.efi`, `\EFI\Microsoft\Boot\bootmgfw.efi`,
   etc. Plus the optional `\EFI\BOOT\BOOTX64.EFI` fallback path.

In the current install, the ESP is `/dev/nvme0n1p1`, the 512MB FAT32
partition. The script mounts it at `/mnt/boot` during install, which means
`/boot` on the running system shows ESP contents directly. That convention
puts the Linux kernel and initramfs on FAT32 alongside the `.efi` files;
trades cleanliness for simplicity. The alternative is mounting the ESP at
`/boot/efi` (or `/efi`) and keeping `/boot` on ext4 with the kernel.

### Boot Entries in NVRAM

Each `BootXXXX` variable in NVRAM contains:

- A label ("GRUB", "Windows Boot Manager", "USB")
- A target partition identified by UUID
- A path to an EFI executable on that partition (e.g. `\EFI\GRUB\grubx64.efi`)

`BootOrder` is the ordered list of which `BootXXXX` entries to try, and in
what order. `BootCurrent` (set at runtime) tells you which entry actually got
you to the current boot.

### The Boot Sequence

1. CPU powers on, runs UEFI firmware from the motherboard flash chip.
2. Firmware initializes hardware, reads NVRAM, gets `BootOrder`.
3. For each entry in `BootOrder`: load the referenced partition (must be
   FAT32-readable), find the `.efi` file at the given path, load it into
   memory, jump into it.
4. The `.efi` file (e.g. GRUB) is now running, but UEFI is still resident
   and providing services (filesystem reads, NVRAM access, screen output).
5. GRUB reads `/boot/grub/grub.cfg`, builds its menu, picks a kernel.
6. GRUB loads the kernel and initramfs into memory, sets up boot args.
7. GRUB calls `ExitBootServices()` — UEFI tears down most services, hands
   the CPU to the kernel.
8. Linux runs from here on out.

If `BootOrder` is exhausted with no successful boot, firmware falls back to
scanning disks for `\EFI\BOOT\BOOTX64.EFI` (the removable-media fallback
path). That's why USB installers boot without requiring an NVRAM entry, and
why the script's step 3.8.4 (copy grubx64.efi to that path) is a useful
safety net.

### Where `.efi` Files Live on the System

**Active, bootable copies live on the ESP** — the only place firmware can
load from. On this install:

```
/boot/EFI/
├── BOOT/BOOTX64.EFI          # fallback path
├── GRUB/grubx64.efi          # primary GRUB
└── (other vendors if dual-boot)
```

The structure is `\EFI\<vendor>\<binary>.efi` by convention. Firmware doesn't
care about the directory name — it follows whatever path is stored in the
NVRAM entry.

**Source/staging copies live in `/usr/lib/`**, dropped by package install:

```
/usr/lib/grub/x86_64-efi/     # GRUB's modules; grub-install builds the .efi from these
/usr/lib/systemd/boot/efi/    # systemd-bootx64.efi
/usr/lib/fwupd/efi/           # firmware updater
/usr/lib/shim/                # shim for secure boot
```

These aren't bootable from where they sit — they're on ext4, which UEFI
can't read. `grub-install` (or `bootctl install` for systemd-boot) is the
bridge: take the package's pristine copy from `/usr/lib/`, optionally
combine with config/modules, write the result to the ESP, register an NVRAM
entry pointing at it.

Some `.efi` files also live inside the firmware itself, baked into the
motherboard flash chip — vendor diagnostic tools, network boot stack, UEFI
shell. These never appear on the filesystem.

## What Went Wrong in the Install

### The Bug

Section 3.8 of the install script had:

```bash
grub_bootloader_exists=$(
  efibootmgr -v | grep -q "grubx64.efi"
  echo $?
)

if [[ $grub_bootloader_exists -ne 0 ]] && [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
fi
```

The check asks "does any NVRAM entry mention `grubx64.efi`?" and treats a
"yes" as "GRUB is already installed, skip."

The problem: NVRAM is shared across all OSes ever installed on the machine.
Wiping sda and sdb cleared the physical disks but left NVRAM untouched. The
stale entries from the previous Pop_OS/Manjaro/whatever installs still listed
`\EFI\<vendor>\grubx64.efi` in their paths. `grep` matched on those, the
condition short-circuited false, and `grub-install` was silently skipped.

By the time `efibootmgr -v` was checked later, consumer firmware had
auto-pruned the orphaned entries during failed boot attempts (most consumer
UEFI does this on cold boot when it tries an entry and the target partition
doesn't exist). That's why only the USB entry showed up post-hoc, hiding the
evidence of what actually caused the bug.

### The Conceptual Mistake

Using NVRAM as a proxy for disk state. NVRAM and disks are independent
storage surfaces:

- NVRAM persists across drive swaps. Wipe a disk, NVRAM entries pointing at
  it remain as dangling references.
- A disk can have a working bootloader and no NVRAM entry (if you copy `.efi`
  files manually but don't run efibootmgr).
- Stale NVRAM entries are the EFI equivalent of dangling pointers — they
  reference partition UUIDs that no longer exist anywhere.

The right question for "should I install GRUB?" is "does
`/mnt/boot/EFI/GRUB/grubx64.efi` exist on the install target?" Only the disk
can answer that.

### Recovery Steps Used

From the live USB, with the bootloader missing:

```bash
sudo mount /dev/nvme0n1p3 /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
for d in dev proc sys run; do sudo mount --bind /$d /mnt/$d; done
sudo mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars

sudo arch-chroot /mnt

pacman -Sy grub efibootmgr  # if not already installed
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /boot/EFI/BOOT
cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI

efibootmgr -v   # confirm GRUB entry now exists
exit
```

The `efivars` bind-mount is important. `arch-chroot` usually handles this,
but if it's missing, `grub-install` writes the `.efi` file successfully but
silently fails to register the NVRAM entry — producing exactly the symptom
that was hit (bootable binary on disk, no firmware pointer to it).

## Script Fixes

### Minimum Fix for the Bootloader Bug

Drop the NVRAM-based check. Gate `grub-install` on whether the file exists on
the install target. Stop swallowing exit codes.

```bash
# 3.8.2 — install GRUB to the ESP
if [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
  log "installing GRUB bootloader"
  arch-chroot /mnt grub-install \
    --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB \
    || { log "ERROR: grub-install failed"; exit 1; }
  changed
fi

# 3.8.3 — generate GRUB config
if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
  log "configuring GRUB bootloader"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg \
    || { log "ERROR: grub-mkconfig failed"; exit 1; }
  changed
fi

# 3.8.4 — fallback BOOTX64.EFI for picky firmware
if [[ ! -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
  log "creating fallback bootloader"
  mkdir -p /mnt/boot/EFI/BOOT
  cp /mnt/boot/EFI/GRUB/grubx64.efi /mnt/boot/EFI/BOOT/BOOTX64.EFI
  changed
fi
```

Delete the `grub_bootloader_exists=$(...)` block entirely.

### Broaden the NVRAM Cleanup in 1.9

The current cleanup loop only removes entries pointing at `install_device`,
and explicitly skips orphaned entries with `[[ -z "$boot_device" ]] && continue`.
Reverse that: orphaned entries are dangling pointers, safe to remove
unconditionally. Lift the whole cleanup out of the "install_device has
partitions" guard — orphan cleanup should run every install regardless.

```bash
# (a) NVRAM hygiene — remove orphaned entries unconditionally
while read -r boot_num uuid; do
  [[ -z "$uuid" ]] && continue
  if ! blkid -U "$uuid" >/dev/null 2>&1; then
    log "removing orphaned boot entry $boot_num"
    efibootmgr -b "$boot_num" -B
  fi
done < <(efibootmgr -v | parse_into_num_and_uuid)

# (b) About-to-wipe cleanup — only if install_device has existing partitions
if lsblk -n "$install_device" | grep -q part; then
  # remove entries whose partition lives on install_device
  ...
fi
```

The conservative "only touch install_device" logic in (b) is still correct
for that block — it's there to protect bootable installs on other disks
(e.g. Windows on a separate drive). What the old code got wrong was applying
that same conservatism to orphaned entries, which by definition can't break
anything.

### Three Separate Concerns

The bootloader-related logic in the script collapses three independent
concerns that the original code mashed together:

1. **NVRAM hygiene.** Remove dangling pointers. Safe to run unconditionally.
   Doesn't care about install_device or anything else.
2. **About-to-wipe cleanup.** Remove NVRAM entries pointing at the install
   target, since those will be invalidated when the disk is reformatted. Only
   relevant when the disk has existing partitions.
3. **Install decision.** Ask: is GRUB on the install target's ESP? If not,
   install. Disk-based check, scoped to the install target.

Each block answers exactly one question. The bug came from a check meant for
(2) being misapplied to (3).

## Multi-Disk / Multi-OS Considerations

Not relevant for single-OS single-disk installs, but worth understanding for
the rewrite.

### Why You Might Want Multiple ESPs

- **Independence from disk removal.** Pull one drive, the others still boot
  because each owns its own bootloader stack.
- **Windows-update self-defense.** Windows has a history of trampling shared
  ESPs. Keeping them separate isolates the damage.
- **Independent install timelines.** Installer A doesn't know what installer
  B will do later; defaulting to self-contained avoids cross-OS assumptions.
- **Redundancy for single-OS setups.** Mirror ESPs across two drives so a
  boot drive failure doesn't brick the machine. Software RAID can't help
  here — UEFI firmware can't read mdadm/LVM, so redundancy has to be at the
  "two complete bootloader copies" level.
- **Hardware quirks.** Some firmware will only boot from internal drives,
  some from the first PCIe disk, etc.

The "one ESP shared between OSes" approach is also valid and common —
particularly for Linux installed alongside an existing Windows. The Arch
wiki recommends this for dual-boot. It trades disk-removal independence for
simplicity.

### BootOrder Management

New installs typically *prepend* their NVRAM entry to `BootOrder`. So if a
machine boots nvme by default, and a second OS is installed on sda, the new
sda entry will land in front of nvme in `BootOrder`. To preserve the
original boot priority:

```bash
efibootmgr -v                 # see entries and current BootOrder
efibootmgr -o XXXX,YYYY,ZZZZ  # set BootOrder explicitly, hex IDs in priority order
```

Useful related commands:

- `efibootmgr -n XXXX` — set BootNext (one-shot override for next boot).
  Useful for testing whether a specific entry boots without committing to
  reordering.
- `efibootmgr -a XXXX` / `-A XXXX` — activate / deactivate an entry without
  deleting it.
- After booting, `efibootmgr` shows `BootCurrent: XXXX`, identifying which
  entry actually loaded the current OS.

### Fall-Through Behavior

If a higher-priority entry's target is gone, firmware falls through to the
next entry. Exact behavior varies:

- Some firmware retries an entry several times before giving up.
- Some firmware falls through silently; others pause with a "boot failed"
  message.
- After enough failed attempts, most consumer firmware marks the entry as
  bad and may eventually delete it (the auto-prune behavior that hid the
  evidence of this debugging session).
- If `BootOrder` is exhausted entirely, firmware falls back to scanning
  disks for `\EFI\BOOT\BOOTX64.EFI`. That's the absolute-last-resort path.

So a redundant setup (nvme primary, sda backup) works like this: nuke nvme,
firmware tries nvme entry, fails, falls through to sda, boots sda's GRUB.
The mechanism is just BootOrder iteration with failure detection.

## Patterns for the Refactor

Beyond the specific bootloader fix, the debugging session surfaced some
patterns worth carrying into the broader rewrite.

### Fail Loud on Critical Commands

The reason this bug survived to production was that `pacman -S`,
`grub-install`, and `grub-mkconfig` all swallow their exit codes. Silent
failure breaks the restart-until-converged design — subsequent passes can't
tell "didn't try" from "tried and failed."

Two options:

- Add `set -euo pipefail` near the top. Will break the idempotent-check
  patterns that intentionally let commands fail (the `pacman -Q` probes,
  `grep -q`, etc.). Those need to be flipped to explicit
  `if ! cmd; then ...`. More refactor but more rigor.
- Wrap the load-bearing commands in `|| { log "ERROR"; exit 1; }`. Lighter
  touch, gets most of the value.

For a restart-until-converged script, exiting loudly is the right
behavior — better to crash on first run than to drift into a broken state
that the next pass can't detect.

### Be Explicit About State Surfaces

The script operates on at least four distinct state surfaces:

- Live USB environment (`/`, the host running the script)
- Chroot environment (`/mnt/...` viewed from outside, `/...` viewed from
  inside `arch-chroot /mnt`)
- The target disk (filesystems, partition tables)
- NVRAM (firmware state, motherboard-resident)

Bugs hide at the boundaries. Naming functions and writing comments in terms
of which surface they operate on (`disk_has_grub_installed`,
`nvram_has_orphaned_entries`, `chroot_pacman_query`) makes confused logic
easier to spot at review time. The bogus NVRAM-as-proxy check would have
been obvious as
"`nvram_mentions_grub_anywhere && !disk_has_grub_installed`" — the
mismatched surfaces stand out.

### Check the Actual Thing, Not a Proxy

The general anti-pattern: ask a question *related* to whether the step is
done, and treat the answer as if it's the question itself.

The script gets this mostly right elsewhere — `[[ ! -d "$home/.oh-my-zsh" ]]`,
`[[ ! -d "/mnt/opt/yay/.git" ]]`, `pacman -Q $pkg`. Each one checks the
actual artifact that the step creates.

The NVRAM check was the outlier. Worth a pass through the rewrite to find
any other "check the proxy" patterns lurking.

### Idempotency Requires Identifying the Artifact

For each step in the script, ask: "what file/directory/configuration does
this step create or modify? Can I check for *that*, exactly?"

- `grub-install` creates `/mnt/boot/EFI/GRUB/grubx64.efi` and an NVRAM entry.
  Check for the file.
- `grub-mkconfig -o /boot/grub/grub.cfg` creates `/boot/grub/grub.cfg`.
  Check for the file.
- `useradd kyle` creates `/etc/passwd` entry and `/home/kyle`. Check
  `id kyle` or the home dir.

When the artifact is composite (multiple files, or settings within a file),
check the most diagnostic one — usually the last thing the step writes.

### Useful Debugging Commands for Future Sessions

```bash
# what's actually in NVRAM
efibootmgr -v

# which entry got us here
efibootmgr | grep BootCurrent

# delete an entry by hex ID
efibootmgr -b XXXX -B

# set BootOrder
efibootmgr -o XXXX,YYYY,...

# one-shot override for next boot
efibootmgr -n XXXX

# inspect ESP contents
ls /boot/EFI/

# verify ESP is FAT32 and right partition type
lsblk -f /dev/nvme0n1p1
sfdisk -d /dev/nvme0n1 | grep -i esp

# am I in UEFI or legacy mode?
ls /sys/firmware/efi    # exists iff UEFI

# is efivars accessible (writable NVRAM from kernel)?
mount | grep efivars
```

## References

- Arch wiki: https://wiki.archlinux.org/title/Arch_boot_process
- Arch wiki: https://wiki.archlinux.org/title/EFI_system_partition
- Arch wiki: https://wiki.archlinux.org/title/GRUB
- UEFI specification: https://uefi.org/specifications (see "Boot Manager" chapter)
- `man efibootmgr`
- `man grub-install`
