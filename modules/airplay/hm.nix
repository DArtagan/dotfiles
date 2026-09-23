{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # `pipewiresink` ships in the pipewire package rather than in any
  # gst-plugins-*, and it is not among uxplay's buildInputs, so the gstreamer
  # setup hook leaves it off the wrapper's plugin path and uxplay aborts with
  # `gst_parse_launch error (audio 1): no element "pipewiresink"`. Adding
  # pipewire here puts it on.
  uxplay = pkgs.uxplay.overrideAttrs (prev: {
    buildInputs = prev.buildInputs ++ [ pkgs.pipewire ];
  });
in
{
  systemd.user.services.uxplay = {
    Unit = {
      Description = "UxPlay AirPlay receiver";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];

    Service = {
      #  -nh      don't append @hostname to the advertised name
      #  -p 7100  pin the ports so ./default.nix can open them statically
      #  -avdec   software h264: the CUDA decoder hands out CUDAMemory, which
      #           videoconvert cannot transform, so the pipeline never
      #           negotiates and the window stays black
      #  -vs xvimagesink  waylandsink cannot take YUV on this box -- an I420
      #           or NV12 caps filter into it fails to produce a window at all,
      #           and uxplay's own I420 frames render to a black surface.
      #           xvimagesink (via XWayland) displays them correctly.
      #           `-vs 0` turns video off and downgrades mirroring to audio.
      #  stdbuf   uxplay's stdout is a pipe to journald, so glibc block-buffers
      #           it and the journal stays empty until the process exits --
      #           which makes every problem here invisible while it happens.
      ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL -eL ${lib.getExe uxplay} -n ${osConfig.networking.hostName} -nh -p 7100 -as pipewiresink -vs xvimagesink -avdec";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
