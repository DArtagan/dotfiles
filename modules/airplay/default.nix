{
  config,
  lib,
  ...
}:
let
  cfg = config.my.airplay;
  uxplayPorts = [
    {
      from = 7100;
      to = 7102;
    }
  ];
in
{
  options.my.airplay.interfaces = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    example = [ "eno1" ];
    description = ''
      Interfaces to accept AirPlay on. uxplay runs with no pin and no
      password, so anything able to reach these ports can play audio through
      this machine and take over its screen — name the home LAN, not every
      interface.

      Interfaces already in `networking.firewall.trustedInterfaces` are open
      regardless and need not be listed; `modules/hotspot` puts its AP there,
      so guests on the hotspot can cast without appearing here.
    '';
  };

  config = {
    services.avahi = {
      enable = true;
      # Opened per interface below instead, so the service is not advertised
      # where it cannot be reached.
      openFirewall = false;
      publish = {
        enable = true;
        # UxPlay registers its AirPlay service through avahi-compat, which
        # counts as a user service.
        userServices = true;
      };
    };

    networking.firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
      allowedTCPPortRanges = uxplayPorts;
      allowedUDPPortRanges = uxplayPorts;
      allowedUDPPorts = [ 5353 ]; # mDNS, without which nothing advertises
    });
  };
}
