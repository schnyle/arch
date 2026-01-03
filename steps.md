
0. Setup
	0.1 Installation configuration
		0.1.1 User
		0.1.2 System
		0.1.3 Script
	0.2 Software lists
		0.2.1 Core packages
		0.2.2 NVIDIA packages
		0.2.3 Virtual machine packages
		0.2.4 VS Code extensions
	0.3 Runtime constants
	0.4 Function definitions
		0.4.1 Logging
		0.4.2 Redirect stdout to log file
		0.4.3 Immediate script restart
		0.4.4 Track changes made
	0.5 Initialize pacman
1. Pre-installation
	1.1 Acquire and installation image
	1.2 Verify signature
	1.3 Prepare an installation medium
	1.4 Boot the live environment
	1.5 Set the console keyboard layout and font
	1.6 Verify the boot mode
	1.7 Connect to the internet
	1.8 Update the system clock
	1.9 Partition the disks
		1.9.1 Get install device from user
		1.9.2 Check for existing device partitions
		1.9.3 Remove any EFI boot entries pointing to install device
		1.9.4 Wipe signatures from install device
		1.9.5 Create new partitions on install device
	1.10 Format the partitions
	1.11 Mount the file systems
2. Installation
	2.2 Install essential packages
	2.1 Select the mirrors
		2.1.1 Install reflector
		2.1.2 Configure reflector
		2.1.3 Enable timer so reflector regularly regenerates mirrors (weekly)
3. Configure the system
	3.1 Fstab
	3.2 Chroot
	3.3 Time
		3.3.1 Set the time zone
		3.3.2 Synchronize system and hardware clocks
	3.4 Localization
		3.4.1 Enable en_US.UTF-8 locale
		3.4.2 Generate locales
		3.4.3 Create locale.conf and set LANG
	3.5 Network configuration
	3.6 Initramfs
	3.7 Root password
	3.8 Boot loader
		3.8.1 Install boot loader packages
		3.8.2 Install GRUB to EFI system partition
		3.8.3 Generate the GRUB configuration file
		3.8.4 Create fallback bootloader for non-compliant UEFI implementations.
4. Reboot
5. Post-installation
	5.1 System preparation
		5.1.1 User setup
			5.1.1.1 Create user
			5.1.1.2 Set password
			5.1.1.3 Allow sudo for wheel group users
			5.1.1.4 Setup temporary passwordless sudo for user
		5.1.2 Enable 32-bit libraries
	5.2 Software installation
		5.2.1 Core pacman packages
		5.2.2 Arch User Repository helper (yay)
			5.2.2.1 Clone repository
			5.2.2.2 Set user ownership
			5.2.2.3 Build and install
		5.2.3 AUR packages
			5.2.3.1 VS Code
			5.2.3.2 VS Code extensions
		5.2.4 NVIDA packages
		5.2.5 Virtual machine packages
		5.2.6 oh-my-zsh
		5.2.7 Minesweeper
		5.2.8 Steam
		5.2.9 Compositor
	5.3 Configuration
		5.3.1 git user.email and user.name
		5.3.2 Configure use default shell to zsh
		5.3.3 Pulse audio
			5.3.3.1 Create systemd directory
			5.3.3.2 Enable user service
			5.3.3.3 .config dir ownership
		5.3.4 Custom dotfiles
		5.3.5 ed25519 key
			5.3.5.1 Generate key
			5.3.5.2 Set permissions
		5.3.6 Setup displays
		5.3.7 Configure dark theme for GTK applications
		5.3.8 Enable NetworkManager service
		5.3.9 Virtual machine
			5.3.9.1 Enable libvirtd.socket
			5.3.9.2 Add use to libvirt group
		5.3.10 symlinks
			5.3.10.1 Minesweeper
			5.3.10.2 pavucontrol
			5.3.10.3 arandr
	5.4 Finalization
		5.4.1 Ensure home directory ownership
		5.4.2 Copy log files to system
		5.4.3 Verify changes
		5.4.4 Remove temporary passwordless sudo file
		5.4.5 Reboot
