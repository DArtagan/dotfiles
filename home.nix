{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      devenv
      direnv
      home-manager
    ];

    username = "will";
    homeDirectory = "/home/will";

    # Exists for the first build, never change this again.
    stateVersion = "24.11";
  };
}
