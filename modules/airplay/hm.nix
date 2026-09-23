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
      ExecStart = "${lib.getExe pkgs.uxplay} -n ${osConfig.networking.hostName} -nh -p 7100 -as pipewiresink -vs 0";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
