{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bemenu
    foot
    i3status-rust
    sway
    swaynotificationcenter
    wayland
    wl-clipboard
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    sway
    fish
    bash
  '';
}
