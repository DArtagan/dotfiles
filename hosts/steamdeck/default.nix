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
      };
    };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nix-steamdeck";
  };

  # Enable the GNOME Desktop Environment.
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    xserver.enable = true;
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
    # Enable users to be trusted users of the Nix store (useful for devenv)
    # TODO: set here to match the one user declared here
    extraOptions = ''
      trusted-users = root willy
      builders-use-substitutes = true
    '';
    settings = {
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
