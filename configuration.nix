{ pkgs, ... }:
{
  imports = [
    modules/audio
    modules/bluetooth
    modules/distributed_builders
  ];

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

  networking = {
    networkmanager.enable = true;
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Clean up nix store storage
      auto-optimise-store = true;

      # cache.nixos.org listed first so a down LAN cache never blocks a build.
      # mini-nas is a home cache on Tailscale (forge.local); when it is offline
      # the daemon can hang querying it and — on nix 2.34.x — crash the whole
      # nix-daemon. `connect-timeout` bounds that wait so an unreachable
      # substituter fails fast and is skipped instead of wedging the switch.
      substituters = [
        "https://cache.nixos.org/"
        "http://mini-nas.forge.local:8770/public"
      ];
      connect-timeout = 5;
      fallback = true;
      trusted-public-keys = [
        "public:YyCDrhNMvRWl7OxoW+8ueMcmVOOc1bllsVCMRNfZWpQ="
      ];
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (pkgs.lib.getName pkg) (import ./unfree-allowlist.nix);

  services = {
    automatic-timezoned.enable = true;
    printing.enable = true;
    tailscale.enable = true;

    # Automatic disk mounting
    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;

    xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Keep automatic timezone detection self-healing. Without this the daemon dies
  # (Restart=no) the first time geoclue idle-times-out mid-query, and the clock
  # stays on the old timezone until the next reboot/rebuild.
  systemd.services.automatic-timezoned.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 30;
  };

  # Re-query location on wake; covers traveling while the machine is suspended,
  # where geoclue never sees a location-change event for the new location.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl try-restart automatic-timezoned.service
  '';

  environment.systemPackages = with pkgs; [
    git
    inxi # hardware info
    lm_sensors # for `sensors` command
    tmux
    vim
    wget
  ];

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
    };
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 2 --optimise";
        dates = "weekly";
      };
    };
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment.variables.EDITOR = "vim";

  users = {
    mutableUsers = false;
  };
}
