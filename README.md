# Arch Install

Automated Arch Linux installation script that follows the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

## Overview

This script automates the standard Arch Linux installation process:

1. **Pre-installation**: Disk partitioning, formatting, and mounting
2. **Installation**: Base system installation with `pacstrap`
3. **Configure the system**: Timezone, locale, hostname, users, bootloader
4. **Reboot**: Into the new system
5. **Post-installation**: User creation, software installation, system configuration

## Usage

Run this command from the Arch live environment:

```bash
curl -fsSL https://raw.githubusercontent.com/schnyle/arch/main/install.sh | \
  tee install.sh | \
  sha256sum -c <(curl -fsSL https://raw.githubusercontent.com/schnyle/arch/main/install.sh.sha256) && \
  chmod +x install.sh && \
  bash install.sh
```

## Post-Installation

After the script completes, you may need to:

- **Update bootloader**: If the script detected an existing bootloader, update it manually:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

- **Configure displays**: Use ARandR to set up multi-monitor configurations:

```bash
displays  # alias for arandr
# Save configuration to ~/.screenlayout/display.sh
# Make executable: chmod +x ~/.screenlayout/display.sh
# Run to apply: ~/.screenlayout/display.sh
```

## Development

After cloning this repo, setup the pre commit hooks with:

```bash
git config core.hooksPath hooks
```

## Requirements

- UEFI system (BIOS support available but not primary focus)
- Internet connection
- At least 4GB RAM recommended
- 20GB+ disk space

