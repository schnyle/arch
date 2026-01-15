
0. Setup
	0.1 Installation configuration
		0.1.1 User
		0.1.2 System
		0.1.3 Script
	0.2 Software lists
		0.2.1 Core packages
	0.3 Function definitions
		0.3.1 Logging
		0.3.2 Redirect stdout to log file
		0.3.3 Immediate script restart
		0.3.4 Track changes made
	0.4 Initialize pacman
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
		3.3.3 Enable NTP time synchronization
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
		5.1.2 Home directory organization
			5.1.2.1 Create user config directory
			5.1.2.2 Create XDG directory mapping file
			5.1.2.3 Disable XDG directory mapping regeneration
			5.1.2.4 Create user home directories
	5.2 Software installation
		5.2.1 Core pacman packages
	5.3 Configuration
		5.3.1 Enable NetworkManager service
		5.3.2 Configure and enable SSH
			5.3.2.1 Configure no root login
			5.3.2.2 Configure non-standard port
			5.3.2.3 Enable sshd service
		5.3.3 Enable avahi-daemon
		5.3.4 Firewall
			5.3.4.1 Bind mount live kernel modules for ufw
			5.3.4.2 Disable IPv6
			5.3.4.3 Default deny incoming
			5.3.4.4 Default allow outgoing
			5.3.4.5 Allow TCP on port [SSH PORT]
			5.3.4.6 Enable ufw service
			5.3.4.7 Enable firewall
		5.3.5 Intrusion prevention
			5.3.5.1 Create fail2ban jail.local config
			5.3.5.2 Enable fail2ban service
	5.4 Finalization
		5.4.1 Ensure user home directory ownership
		5.4.2 Copy log files to system
		5.4.3 Verify changes
		5.4.4 Remove temporary passwordless sudo file
		5.4.5 Reboot
