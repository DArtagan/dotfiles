{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bemenu
    brightnessctl
    i3status-rust
    grim
    sway
    swayidle
    swaylock
    swaynotificationcenter
    wayland
    wl-clipboard
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
        user = "greeter";
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    sway --unsupported-gpu
    fish
    bash
  '';

  programs.sway = {
    enable = true;
    extraPackages = [ ];
    wrapperFeatures.gtk = true;
  };

  # xdg portal + pipewire = screensharing
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  #home-manager.users.${config.username} = {

  #};
}
