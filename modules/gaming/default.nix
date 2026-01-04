{ pkgs, ... }:
{
  hardware.graphics.enable32Bit = true; # Needed for Epic Game Store

  environment.systemPackages = with pkgs; [
    lutris
    wineWowPackages.stagingFull # Epic only works when run against the latest version of wine (circa 2026-01-04)
    pkgs.winetricks
  ];

  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };
  };
}
