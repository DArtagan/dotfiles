_: {
  imports = [
    #./hardware-configuration.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.memtest86.enable = true;
    };

    supportedFilesystems = [ "zfs" ];

    tmp.useTmpfs = true;

    zfs.devNodes = "/dev/";
  };

  services.zfs = {
    trim.enable = true;
    autoScrub = {
      enable = true;
      pools = [ "rpool" ];
    };
  };

  # services.sanoid  # TODO: zfs auto-snapshotting

  # TODO: have opted to manually edit the hardware configuration, adding `options = [ "zfsutil" ];` to each of the applicable entries, which should get around the below.  Delete if it is indeed unnecessary.
  #systemd.services.zfs-mount.enable = false; # Prevents NixOS/systemd mount management from conflicting with ZFS's native.

  fileSystems = {
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
      # the zfsutil option is needed when mounting zfs datasets without "legacy" mountpoints
      options = [ "zfsutil" ];
    };

    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
  };

  networking = {
    hostId = "bcd82e4b"; # Randomly generated
    hostName = "thenixbeast";
  };

  # Nvidia
  hardware.graphics.enable = true;
  hardware.nvidia.open = true;
  services.xserver.videoDrivers = [ "nvidia" ]; # Yes it says 'xserver', it also loads for Wayland

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database
  # versions on your system were taken. It‘s perfectly fine and
  # recommended to leave this value at the release version of the first
  # install of this system. Before changing this value read the
  # documentation for this option (e.g. man configuration.nix or on
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
