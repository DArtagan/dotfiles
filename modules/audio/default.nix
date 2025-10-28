{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pavucontrol
  ];

  security.rtkit.enable = true;
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;
    };
    playerctld.enable = true; # Enable keyboard media controls
    pulseaudio.enable = false;
  };
}
