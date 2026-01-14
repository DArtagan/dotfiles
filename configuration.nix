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
  time.timeZone = "America/New_York";

  networking = {
    networkmanager.enable = true;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 90d";
    };

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Clean up nix store storage
      auto-optimise-store = true;

      substituters = [
        "http://mini-nas.forge.local:8770/public"
      ];
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
  nixpkgs.config.allowUnfree = true;

  services = {
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
      #clean = {
      #  enable = true;
      #  extraArgs = "--keep-since 90d --keep 2";
      #};
    };
  };

  environment.variables.EDITOR = "vim";

  users = {
    mutableUsers = false;
  };
}
