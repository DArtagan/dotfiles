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
  # nixpkgs' uxplay lists these in buildInputs but installs a bare, unwrapped
  # ELF, so GStreamer never sees them: `gst-inspect-1.0 waylandsink` comes up
  # empty and the service aborts at startup with
  # `gst_parse_launch error (audio 1): no element "pipewiresink"`.
  # Audio alone would need only a sink (uxplay decodes ALAC itself), but
  # mirroring also needs a parser, a decoder and a video sink.
  gstPlugins = with pkgs.gst_all_1; [
    pkgs.pipewire # pipewiresink
    gstreamer # queue, capsfilter (in its `out`, not its default `bin`)
    gst-plugins-base # videoconvert, audioconvert, playback
    gst-plugins-good # autodetect and friends
    gst-plugins-bad # waylandsink, h264parse
    gst-libav # avdec_h264
  ];
  uxplay = pkgs.symlinkJoin {
    name = "uxplay-with-gst-plugins";
    paths = [ pkgs.uxplay ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/uxplay \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${
          lib.makeSearchPathOutput "out" "lib/gstreamer-1.0" gstPlugins
        }"
    '';
  };
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
      ExecStart = "${pkgs.coreutils}/bin/stdbuf -oL -eL ${uxplay}/bin/uxplay -n ${osConfig.networking.hostName} -nh -p 7100 -as pipewiresink -vs xvimagesink -avdec";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
