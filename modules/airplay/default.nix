# AirPlay receiver: play iPhone audio through this machine's speakers.
#
# NixOS half: mDNS publishing plus the fixed ports UxPlay is pinned to. The
# server itself runs in the user session (./hm.nix), because it has to reach
# that session's PipeWire. See ./README.md.
_: {
  services.avahi = {
    enable = true;
    openFirewall = true; # UDP 5353, without which nothing advertises
    publish = {
      enable = true;
      # UxPlay registers its AirPlay service through avahi-compat, which counts
      # as a user service.
      userServices = true;
    };
  };

  # UxPlay is started with `-p 7100`, i.e. 7100-7102 on both protocols. Pinning
  # them is the only reason a static firewall rule is possible: left alone it
  # picks three random ports per run.
  networking.firewall = {
    allowedTCPPortRanges = [
      {
        from = 7100;
        to = 7102;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 7100;
        to = 7102;
      }
    ];
  };
}
