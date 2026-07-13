{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.tailscale;
in
{
  options.my.tailscale = {
    operator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "will";
      description = ''
        Username granted Tailscale operator access, allowing that user to run
        `tailscale up` / `tailscale set` (e.g. the ts-routes / ts-exit helpers)
        without sudo. Applied on a fresh `tailscale up`.
      '';
    };

    loginServer = lib.mkOption {
      type = lib.types.str;
      default = "https://headscale.immortalkeep.com";
      description = ''
        Headscale coordination server URL. Pinned so a fresh `tailscale up`
        targets our self-hosted control plane instead of Tailscale's SaaS.
      '';
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Accept the DNS config (MagicDNS) pushed by Headscale. This tailnet
        REQUIRES `true` — without it, `*.forge.local` names (e.g.
        `mini-nas.forge.local`) fail to resolve (NXDOMAIN). Headscale advertises
        reachable public resolvers, so enabling this is not a black-hole risk.
        See ./README.md.
      '';
    };
  };

  config = {
    environment.systemPackages = [ pkgs.tailscale ];
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "client";
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
    };

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";
      serviceConfig.Type = "oneshot";

      # Make sure tailscale is running before trying to connect to tailscale
      after = [
        "network-pre.target"
        "tailscale.service"
      ];
      wants = [
        "network-pre.target"
        "tailscale.service"
      ];
      wantedBy = [ "multi-user.target" ];

      # Have the job run this shell script.
      #
      # NOTE: no --authkey by design. A reusable Headscale pre-auth key is a
      # single point of failure for the whole tailnet, so fresh machines are
      # registered interactively (see ./README.md). This unit only pins the
      # invariants (login server, DNS, operator); it will time out and no-op on
      # a brand-new host until that host is registered out-of-band.
      script = with pkgs; ''
        # Wait for tailscaled to settle
        sleep 2

        # Check if we are already authenticated to tailscale
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # If so, then do nothing
          exit 0
        fi

        ${tailscale}/bin/tailscale up --timeout 60s \
          --login-server=${cfg.loginServer} \
          --accept-dns=${lib.boolToString cfg.acceptDns} \
          ${lib.optionalString (cfg.operator != null) "--operator=${cfg.operator}"} || true
      '';
    };
  };
}
