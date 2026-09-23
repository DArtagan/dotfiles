# Home-manager half of the airplay module: the UxPlay server.
#
# Pairs with ./default.nix (avahi + firewall). This has to be a *user* service:
# PipeWire runs per-session here, so a system daemon would have no sink to play
# into. See ./README.md.
{
  pkgs,
  osConfig,
  ...
}:
let
  # nixpkgs wraps uxplay with gst-plugins-{base,good,bad,ugly} and gst-libav,
  # but `pipewiresink` ships inside the pipewire package itself, so it is not
  # on the plugin path and uxplay aborts at startup with
  # `gst_parse_launch error (audio 1): no element "pipewiresink"`.
  uxplay = pkgs.symlinkJoin {
    name = "uxplay-with-pipewire";
    paths = [ pkgs.uxplay ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/uxplay \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${pkgs.pipewire}/lib/gstreamer-1.0
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
      #  -nh     don't append @hostname to the advertised name
      #  -p 7100 pin the ports so ./default.nix can open them statically
      #  -vs 0   audio only; `-vs waylandsink` also accepts screen mirroring
      ExecStart = "${uxplay}/bin/uxplay -n ${osConfig.networking.hostName} -nh -p 7100 -as pipewiresink -vs 0";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
