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
        `tailscale up` / `tailscale set` (e.g. the ts-exit helper)
        without sudo. Applied on a fresh `tailscale up`.
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
      # invariants (login server, DNS, routes, operator); it will time out and
      # no-op on a brand-new host until that host is registered out-of-band.
      #
      # Everything but the operator username is a literal below. Each has one
      # value this tailnet works with, so a knob would only offer a way to
      # break it.
      #   --accept-dns=false  -> *.forge.local goes NXDOMAIN; MagicDNS is the
      #     only thing serving it, and the resolvers Headscale advertises are
      #     public, so there is no black-hole risk to hedge against.
      #   --accept-routes=false -> *.immortalkeep.com stops resolving away from
      #     the LAN, since vulcanus' 192.168.0.0/24 is the only path to CoreDNS
      #     and the internal ingress. Safe on-LAN too: Tailscale declines to
      #     install a route matching the host's own interface subnet.
      script = with pkgs; ''
        # Wait for tailscaled to settle
        sleep 2

        # An already-registered host must NOT be sent through `tailscale up` —
        # it would re-prompt for login. It still has to converge on the pinned
        # values though, so apply them with `tailscale set`, which is a local
        # daemon call and works even with no network. Skipping this and
        # returning early would make the pinned values declarative in name
        # only: nothing would ever reach a machine that is already registered.
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ "$status" = "Running" ]; then
          ${tailscale}/bin/tailscale set \
            --accept-dns=true \
            --accept-routes=true \
            ${lib.optionalString (cfg.operator != null) "--operator=${cfg.operator}"} || true
          exit 0
        fi

        # --login-server is only settable at login, which is why it is here and
        # not in the `set` call above. Without it a bare `tailscale up` targets
        # Tailscale's SaaS coordinator instead of our own.
        ${tailscale}/bin/tailscale up --timeout 60s \
          --login-server=https://headscale.immortalkeep.com \
          --accept-dns=true \
          --accept-routes=true \
          ${lib.optionalString (cfg.operator != null) "--operator=${cfg.operator}"} || true
      '';
    };
  };
}
