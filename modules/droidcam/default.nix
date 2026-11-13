{ pkgs, ... }:
{
  programs = {
    obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
      ];
    };
  };

  # OBS's virtual camera is video-only, so DroidCam's audio never leaves OBS.
  # This loopback is a virtual mic: a sink ("OBS Mic Feed") that OBS monitors
  # into, wired to a source ("OBS Mic") that browsers and apps can pick. In OBS,
  # set Settings > Audio > Advanced > Monitoring Device to "OBS Mic Feed", and
  # the DroidCam source's Advanced Audio Properties > Audio Monitoring to
  # "Monitor Only (mute output)".
  services.pipewire.extraConfig.pipewire."90-obs-mic" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "OBS Mic";
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = "obs_mic_feed";
            "node.description" = "OBS Mic Feed";
            "media.class" = "Audio/Sink";
          };
          "playback.props" = {
            "node.name" = "obs_mic";
            "node.description" = "OBS Mic";
            "media.class" = "Audio/Source";
          };
        };
      }
    ];
  };
}
