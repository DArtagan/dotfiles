{ config, ... }:
{
  imports = [
    #./hardware-configuration.nix
  ];

  sops =
    let
      host_ssh_private_key = "/etc/ssh/ssh_host_ed25519_key";
      user_ssh_private_key = "/home/will/.ssh/id_ed25519";
    in
    {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ host_ssh_private_key ];
      environment.SOPS_AGE_SSH_PRIVATE_KEY_FILE = host_ssh_private_key;
      secrets = {
        "users/will/hashedPassword".neededForUsers = true;
        "users/will/ssh_private_key" = {
          owner = "will";
          mode = "600";
          path = user_ssh_private_key;
        };
        "users/will/ssh_public_key" = {
          owner = "will";
          mode = "644";
          path = user_ssh_private_key + ".pub";
        };
      };
    };

  boot = {
    loader = {
      # TODO: once moved off of manjaro, consider condensing this and the steamdeck bootloader declaration, into just using systemd-boot in configuration.nix
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
        useOSProber = true;
        memtest86.enable = true;
      };
      timeout = 20;
    };

    supportedFilesystems = [ "zfs" ];

    tmp.useTmpfs = true;

    zfs.devNodes = "/dev/";
  };

  services.zfs = {
    trim.enable = true;
    autoScrub = {
      enable = true;
    };
  };

  # services.sanoid  # TODO: zfs auto-snapshotting

  # TODO: have opted to manually edit the hardware configuration, adding `options = [ "zfsutil" ];` to each of the applicable entries, which should get around the below.  Delete if it is indeed unnecessary.
  #systemd.services.zfs-mount.enable = false; # Prevents NixOS/systemd mount management from conflicting with ZFS's native.

  fileSystems = {
    "/" = {
      device = "rpool/root";
      fsType = "zfs";
      # the zfsutil option is needed when mounting zfs datasets without "legacy" mountpoints
      options = [ "zfsutil" ];
    };

    "/nix" = {
      device = "rpool/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/var" = {
      device = "rpool/var";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/home" = {
      device = "rpool/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/boot" = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part1";
      fsType = "vfat";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part7"; }
  ];

  networking = {
    hostId = "bcd82e4b"; # Randomly generated
    hostName = "thenixbeast";
  };

  # Nvidia
  hardware.graphics.enable = true;
  hardware.nvidia.open = true;
  services.xserver.videoDrivers = [ "nvidia" ]; # Yes it says 'xserver', it also loads for Wayland

  users.users = {
    will = {
      # TODO: impermanence, https://github.com/Mic92/sops-nix?tab=readme-ov-file#setting-a-users-password
      hashedPasswordFile = config.sops.secrets."users/will/hashedPassword".path;
      home = "/home/will";
      description = "Will";
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "podman"
        "wheel"
      ];
    };
  };

  programs = {
    _1password-gui = {
      # TODO: set here to match the one user declared here
      polkitPolicyOwners = [ "will" ];
    };
  };

  nix = {
    # Enable users to be trusted users of the Nix store (useful for devenv)
    # TODO: set here to match the one user declared here
    extraOptions = ''
      trusted-users = root will
      builders-use-substitutes = true
    '';
    settings = {
      cores = 6;
    };
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database
  # versions on your system were taken. It‘s perfectly fine and
  # recommended to leave this value at the release version of the first
  # install of this system. Before changing this value read the
  # documentation for this option (e.g. man configuration.nix or on
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
