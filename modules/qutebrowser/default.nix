{ config, pkgs, ... }:
{

  home = {
    file."${config.xdg.configHome}/qutebrowser" = {
      source = ../../qutebrowser/.config/qutebrowser;
      recursive = true;
    };

    packages = with pkgs; [
      qutebrowser
    ];
  };
}
