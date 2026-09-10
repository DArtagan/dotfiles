{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
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

  # Without this the card sits in regulatory domain 00 (the world domain), which
  # marks all of 5 GHz passive-scan: the radio waits to overhear a beacon rather
  # than probing for the network, and transmit power is capped. Seen as
  # NetworkManager reporting "the Wi-Fi network could not be found" for an AP
  # its own scan list contained, and repeated "association took too long".
  # hostapd sets the domain from its country_code while the hotspot runs and it
  # reverts to 00 when hostapd stops, so the radio is otherwise only correct
  # while the hotspot happens to be up.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="US"
  '';

  networking = {
    hostName = "steamdeck";

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
