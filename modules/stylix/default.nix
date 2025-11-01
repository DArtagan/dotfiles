{ pkgs, ... }:
{
  #stylix = {
  #  #targets.firefox.enable = false;
  #  #targets.firefox.profileNames = [ "will" ];
  #};

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-light.yaml";
    image = ./wallpaper.png;
    fonts = {
      monospace.name = "Hack Nerd Font";
      sizes = {
        desktop = 12;
        popups = 12;
        terminal = 11;
      };
    };
  };
}
