# `soyuz` [Dell XPS 15 9570 + Debian]

## Pre-installation

Before installing the system, it is important to take into account that:

1. It is important to **switch the latopt's operation from RAID/IDE to AHCI**
   before tuning anything else. Not doing so can toast one or the other
   installation. I followed [this tutorial](https://triplescomputers.com/blog/uncategorized/solution-switch-windows-10-from-raidide-to-ahci-operation/)
   with great results.
   
2. Right after that, the Windows partition must be shrunk from Windows itself
   before partitioning.
   
3. Create (at least) an `ext4` partition and mount `/` in it. Locate the UEFI
   partition and mount `/boot/efi` in it **without formatting it**.

These are the main steps to take into account while installing. Once completed,
you should have a working Windows installation and a minimal Debian one
running.

## Kernel flags

When running Debian, I use the following flags to boot the kernel:
- `quiet loglevel=2`, to minimize the number of messages when booting. 
- `acpi_rev_override=1 acpi_osi=Linux`, to use the appropriate ACPI
  configuration.
- `nouveau.modeset=0 nouveau.runpm=0`, to disable the drivers once the nvidia
ones are added.
- `scsi_mod.use_blk-mq=1 pcie_aspm=force`, to have some minimal performance
  improvements.
- `acpi_backlight=vendor`, to have working brightness controls.
