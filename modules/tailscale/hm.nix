# Home-manager half of the tailscale module: user-facing CLI helpers.
#
# Pairs with ./default.nix (the NixOS service). Imported per-user in flake.nix
# on hosts that manage tailscale declaratively. The helpers only need the
# `tailscale` CLI and `jq` in PATH. See ./README.md.
_: {
  programs.fish.functions = {
    # Toggle acceptance of tailnet subnet routes at runtime (persists via
    # `tailscale set`, so the bare `tailscale up` in the autoconnect service
    # keeps whatever you last chose). Turn ON at an untrusted/remote network
    # to reach tailnet subnets; OFF when using the local LAN directly.
    ts-routes = ''
      switch "$argv[1]"
        case on true
          tailscale set --accept-routes=true
          and echo "tailscale: accept-routes ON — tailnet subnet routes accepted"
        case off false
          tailscale set --accept-routes=false
          and echo "tailscale: accept-routes OFF — using local network directly"
        case toggle
          if test (tailscale debug prefs | jq -r .RouteAll) = true
            tailscale set --accept-routes=false
            and echo "tailscale: accept-routes OFF"
          else
            tailscale set --accept-routes=true
            and echo "tailscale: accept-routes ON"
          end
        case status ""
          echo "accept-routes: "(tailscale debug prefs | jq -r .RouteAll)
        case '*'
          echo "usage: ts-routes [on|off|toggle|status]" >&2
          return 1
      end
    '';
    # Route ALL internet traffic through a tailnet exit node (privacy on
    # untrusted wifi). `--exit-node-allow-lan-access` keeps the local LAN
    # (printers, NAS) reachable. Run with no args to see current + choices.
    ts-exit = ''
      switch "$argv[1]"
        case off none clear
          tailscale set --exit-node=
          and echo "tailscale: exit node cleared — direct internet via local link"
        case "" status
          echo "current exit-node: "(tailscale debug prefs | jq -r 'if .ExitNodeIP == "" then "none" else .ExitNodeIP end')
          echo
          echo "available exit nodes:"
          tailscale exit-node list
        case '*'
          tailscale set --exit-node="$argv[1]" --exit-node-allow-lan-access=true
          and echo "tailscale: all traffic via exit node '$argv[1]' (local LAN still reachable)"
      end
    '';
  };
}
