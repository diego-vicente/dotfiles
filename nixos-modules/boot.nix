{ pkgs, options }:

{
  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.efi.canTouchEfiVariables = true;

    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      # GOTCHA: check the available boot space using `df -h /boot`
      configurationLimit = options.maxGenerations;
      useOSProber = true;
    };

    # FIXME: None of these flags work properly yet
    # kernelParams = [
    #   # Configure the kernel to use the ACPI controls (Dell XPS 15 9560
    #   # specific)
    #   "pcie_port_pm=off"
    #   "acpi_backlight=vendor"
    #   "acpi_osi=Linux"
    #   "acpi_osi=!"
    #   ''acpi_osi="Windows 2009"''
    #   # Enable the DZ60RGB ANSI v2 PCB to be used during boot. Without this flag
    #   # the keyboard works fine but there cannot be used to select the boot
    #   # method. This fix is not general, but this is the way to infer it:
    #   #   1. `0x445a:0x1221` is the vendor and device ID. This will tell which
    #   #      device gets affected by the flag. This information is given by the
    #   #      `lsusb` command - just remember to add the 0x prefixes!
    #   #   2. `0x20000408` is a stack of flags. This is general and probably
    #   #      fixes similar problems, searching for it on the internet returns
    #   #      plenty examples. The actual flags are:
    #   #        #define HID_QUIRK_NOGET 0x00000008
    #   #        #define HID_QUIRK_ALWAYS_POLL 0x00000400
    #   #        #define HID_QUIRK_NO_INIT_REPORTS 0x20000000
    #   "usbhid.quirks=0x445a:0x1221:0x20000408"
    # ];
  };
}
