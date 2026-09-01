{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # evdi 1.14.15 does not build against Linux 7.2: DRM renamed the atomic
  # callback argument (drm_atomic_state -> drm_atomic_commit), and evdi's
  # conftest.sh probes silently misdetect the kernel API because the test
  # compiles lack KBUILD_MODNAME. Bump to 1.15.0 + the upstream conftest fix.
  # TODO: drop this once nixpkgs#555981 lands.
  nixpkgs.overlays = [
    (final: prev: {
      linuxPackagesFor =
        kernel:
        (prev.linuxPackagesFor kernel).extend (
          _: kprev: {
            evdi = kprev.evdi.overrideAttrs (old: rec {
              version = "1.15.0";
              src = final.fetchFromGitHub {
                owner = "DisplayLink";
                repo = "evdi";
                tag = "v${version}";
                hash = "sha256-CXF7PvmrPjjNoWXbWxEkFE/Sw4bO6YqDplPwF/OxhB0=";
              };
              # 1.15.0 dropped the /etc/os-release distro detection this patched.
              prePatch = "";
              patches = (old.patches or [ ]) ++ [ ./evdi-fix-conftest-probes.patch ];
            });
          }
        );
    })
  ];

  sops =
    let
      host_ssh_private_key = "/etc/ssh/ssh_host_ed25519_key";
      user_ssh_private_key = "/home/willy/.ssh/id_ed25519";
    in
    {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ host_ssh_private_key ];
      environment.SOPS_AGE_SSH_PRIVATE_KEY_FILE = host_ssh_private_key;
      secrets = {
        "users/willy/hashedPassword".neededForUsers = true;
        "users/willy/ssh_private_key" = {
          owner = "willy";
          mode = "600";
          path = user_ssh_private_key;
        };
        "users/willy/ssh_public_key" = {
          owner = "willy";
          mode = "644";
          path = user_ssh_private_key + ".pub";
        };
        "users/willy/wireguard_private_key" = { };
        "wifi/hotspot_psk" = { };
      };
    };

  # Lives here rather than with the other `my.*` settings in flake.nix because
  # pskFile has to reference this host's sops secret.
  my.hotspot = {
    enable = true;
    ssid = "steam_powered_internet";
    pskFile = config.sops.secrets."wifi/hotspot_psk".path;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 15;
    };
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "steamdeck";

    #interfaces."wlo1_prime" = {
    #
    #};

    wg-quick.interfaces = {
      # Launch using: `sudo systemctl restart wg-quick-wg0.service`
      wg0 = {
        # TODO: make the rest of this wireguard config a reusable module across hosts, with this address and privateKey the only things passed in.
        address = [ "10.0.1.11/32" ];
        autostart = false;
        dns = [
          "192.168.0.202"
          "1.1.1.1"
        ];
        privateKeyFile = config.sops.secrets."users/willy/wireguard_private_key".path;
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

  # Enable the GNOME Desktop Environment.
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    xserver.enable = true;

    # Dell USB-C DisplayLink adapter. "displaylink" pulls in the evdi kernel
    # module + the dlm (DisplayLink Manager) service, which the compositor
    # picks up as an extra DRM output. "modesetting" keeps the internal AMD
    # display working. Requires the unfree driver blob to be added to the Nix
    # store manually (Synaptics forbids redistribution) — the build will print
    # the exact URL + `nix-store --add-fixed` command if it is missing.
    xserver.videoDrivers = [
      "displaylink"
      "modesetting"
    ];
  };

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator # app icon system tray
  ];

  # TODO: unify usernames to `will` and move this all to configuration.nix
  users.users = {
    willy = {
      # TODO: impermanence, https://github.com/Mic92/sops-nix?tab=readme-ov-file#setting-a-users-password
      hashedPasswordFile = config.sops.secrets."users/willy/hashedPassword".path;
      home = "/home/willy";
      description = "Willy";
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };

  programs = {
    _1password-gui = {
      # TODO: set here to match the one user declared here
      polkitPolicyOwners = [ "willy" ];
    };
  };

  nix = {
    settings = {
      # Enable users to be trusted users of the Nix store (useful for devenv)
      # TODO: set here to match the one user declared here
      trusted-users = [ "willy" ];
      cores = 4;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database
  # versions on your system were taken. It‘s perfectly fine and
  # recommended to leave this value at the release version of the first
  # install of this system. Before changing this value read the
  # documentation for this option (e.g. man configuration.nix or on
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
