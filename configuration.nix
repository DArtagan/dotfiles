{ config, pkgs, ... }:
{
  imports = [
    modules/audio
    modules/distributed_builders
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Locality
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  time.timeZone = "America/New_York";

  networking = {
    firewall.allowedUDPPorts = [ 51820 ]; # Wireguard

    # Enable networking
    networkmanager.enable = true;

    wg-quick.interfaces = {
      # Launch using: `sudo systemctl restart wg-quick-wg0.service`
      wg0 = {
        address = [ "10.0.1.10/32" ];
        autostart = false;
        dns = [
          "192.168.0.202"
          "1.1.1.1"
        ];
        #listenPort = 51820;
        privateKeyFile = "/etc/wireguard/private.key";
        peers = [
          {
            publicKey = "ky2MMTdJmLKAT/QwgUNpRCmXJb1Mn4Qs/51rqFq6/jo=";
            allowedIPs = [
              "0.0.0.0/0"
              "::/0"
            ];
            # Or only particular subnets
            #allowedIPs = [ "10.0.1.0/24", "10.0.0.0/24", "192.168.0.0/24" ];
            endpoint = "immortalkeep.com:51820";
            persistentKeepalive = 25;
          }
        ];
        #postUp = "ping -c1 10.0.1.1";
      };
    };
  };

  nix = {
    # Enable users to be trusted users of the Nix store (useful for devenv)
    extraOptions = ''
      trusted-users = root willy
      builders-use-substitutes = true
    '';

    # Enable flakes support
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Clean up nix store storage
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  services = {
    printing.enable = true;
    tailscale.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };

  environment.systemPackages = with pkgs; [
    git
    lm_sensors # for `sensors` command
    tmux
    vim
    wget
  ];

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "willy" ];
    };
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 90d --keep 2";
      };
    };
  };

  environment.variables.EDITOR = "vim";

  users.users.willy = {
    isNormalUser = true;
    description = "Willy";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
