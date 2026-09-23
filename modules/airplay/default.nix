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

  # `-p 7100` does not pin one port: uxplay needs three TCP and three UDP, and
  # -p sets the base, so it takes 7100, 7101 and 7102 on both protocols. The
  # range matches exactly. Pinning is what makes a static rule possible at all:
  # left alone uxplay picks three random ports per run.
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
