# Arch - Personal

Installation script for personal machines.

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
