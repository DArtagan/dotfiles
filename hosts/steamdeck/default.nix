{ jovian-nixos, pkgs }:
{
  imports = [
    ./hardware-configuration.nix
    jovian-nixos.nixosModules.default
    {
      jovian = {
        devices.steamdeck = {
          enable = true;
          autoUpdate = true;
        };
        hardware.has.amd.gpu = true;
        steam.enable = true;
        steamos.useSteamOSConfig = true;
      };
    }
  ];

  networking = {
    hostName = "nix-steamdeck";
  };

  # Enable the GNOME Desktop Environment.
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  packages = with pkgs; [
    gnomeExtensions.appindicator # app icon system tray
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database
  # versions on your system were taken. It‘s perfectly fine and
  # recommended to leave this value at the release version of the first
  # install of this system. Before changing this value read the
  # documentation for this option (e.g. man configuration.nix or on
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
