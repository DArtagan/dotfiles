{ config, pkgs, ... }:
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
        "users/will/wireguard_private_key" = { };
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

  services = {
    esphome.enable = true; # For connecting to and programming ESP32 microcontrollers
    gnome.gnome-keyring.enable = true; # So 1Password can store its vault 2FA locally
    lact = {
      # GPU optimization/overclocking/undervolting
      enable = true;
      settings = {
        version = 5;
        daemon = {
          log_level = "info";
          admin_group = "wheel";
          disable_clocks_cleanup = false;
        };
        apply_settings_timer = 5;
        gpus = {
          "10DE:2684-10DE:165B-0000:01:00.0" = {
            fan_control_enabled = false;
            power_cap = 600.0;
            min_core_clock = 210;
            max_core_clock = 2725;
            gpu_clock_offsets = {
              "0" = 315;
            };
            mem_clock_offsets = {
              "0" = 1500;
            };
          };
        };
        current_profile = null;
        auto_switch_profiles = false;
      };
    };
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no"; # disable root login
        PasswordAuthentication = false; # disable password login, require keys
      };
      openFirewall = true;
    };
    zfs = {
      trim.enable = true;
      autoScrub = {
        enable = true;
      };
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

    "/mnt/manjaro" = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part4";
      fsType = "ext4";
    };

    "/mnt/mamba" = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part6";
      fsType = "ext4";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part7"; }
  ];

  networking = {
    hostId = "bcd82e4b"; # Randomly generated
    hostName = "thenixbeast";

    wg-quick.interfaces = {
      wg0 = {
        address = [ "10.0.1.10/32" ];
        autostart = false;
        dns = [
          "192.168.0.202"
          "1.1.1.1"
        ];
        privateKeyFile = config.sops.secrets."users/will/wireguard_private_key".path;
        peers = [
          {
            publicKey = "ky2MMTdJmLKAT/QwgUNpRCmXJb1Mn4Qs/51rqFq6/jo=";
            allowedIPs = [
              "10.0.1.0/24"
              "192.168.0.0/24"
            ];
            endpoint = "immortalkeep.com:51820";
          }
        ];
        postUp = [
          "${pkgs.inetutils}/bin/ping -c1 10.0.1.1"
        ];
      };
    };

  };

  hardware = {
    bluetooth.enable = true;
    graphics.enable = true;
    libftdi.enable = true; # For connecting to and programming ESP32 microcontrollers
    nvidia.open = true;
    xone.enable = true; # Xbox One wireless adapter
  };
  services.xserver.videoDrivers = [ "nvidia" ]; # Yes it says 'xserver', it also loads for Wayland

  users.users = {
    will = {
      # TODO: impermanence, https://github.com/Mic92/sops-nix?tab=readme-ov-file#setting-a-users-password
      hashedPasswordFile = config.sops.secrets."users/will/hashedPassword".path;
      home = "/home/will";
      description = "Will";
      isNormalUser = true;
      extraGroups = [
        "dialout"
        "networkmanager"
        "podman"
        "tty"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYSwODOrerKkBNuitwqjNioFXLDRBKqSJTayFoo1Ude willy@steamdeck"
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
    settings = {
      # Enable users to be trusted users of the Nix store (useful for devenv)
      # TODO: set here to match the one user declared here
      trusted-users = [ "will" ];
      cores = 12;
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
