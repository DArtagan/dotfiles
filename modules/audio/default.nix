{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];

  security.rtkit = {
    enable = true;
    # rtkit's default RLIMIT_RTTIME cap (200ms) is too tight for PipeWire >=1.4's
    # client.conf, which requests a larger realtime CPU budget; clients that
    # actually use it get silently SIGKILLed by the kernel the instant they cross
    # rtkit's cap (no OOM/cgroup/coredump trace -- it's a raw RLIMIT_RTTIME kill).
    # Hit this with Mumble: https://github.com/mumble-voip/mumble/issues/6780
    # TODO: remove when issue closed
    args = [ "--rttime-usec-max=5000000" ];
  };
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      jack.enable = true;
    };
    playerctld.enable = true; # Enable keyboard media controls
    pulseaudio.enable = false;
  };
}
