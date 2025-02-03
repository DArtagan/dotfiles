{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      devenv
      home-manager
    ];
  };

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
