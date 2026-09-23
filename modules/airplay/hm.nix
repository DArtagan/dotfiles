# Home-manager half of the airplay module: the UxPlay server.
#
# Pairs with ./default.nix (avahi + firewall). This has to be a *user* service:
# PipeWire runs per-session here, so a system daemon would have no sink to play
# into. See ./README.md.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # nixpkgs' uxplay already wraps its binary with GST_PLUGIN_SYSTEM_PATH_1_0
  # covering gstreamer, -base, -good, -bad, -ugly and -libav. `pipewiresink`
  # is the one element it needs that lives outside all of those (it ships in
  # the pipewire package), and without it the service aborts at startup with
  # `gst_parse_launch error (audio 1): no element "pipewiresink"`. Adding
  # pipewire to buildInputs lets the existing gstreamer setup hook extend the
  # wrapper, rather than wrapping the wrapper a second time.
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
