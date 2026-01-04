# Arch

Automated Arch Linux installation scripts that follows the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

## Overview

This script automates the standard Arch Linux installation process:

1. **Pre-installation**: Disk partitioning, formatting, and mounting
2. **Installation**: Base system installation with `pacstrap`
3. **Configure the system**: Timezone, locale, hostname, users, bootloader
4. **Reboot**: Into the new system
5. **Post-installation**: User creation, software installation, system configuration

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
