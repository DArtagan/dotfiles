# Home-manager half of the tailscale module: user-facing CLI helpers.
#
# Pairs with ./default.nix (the NixOS service). Imported per-user in flake.nix
# on hosts that manage tailscale declaratively. The helpers only need the
# `tailscale` CLI and `jq` in PATH. See ./README.md.
_: {
  programs.fish.functions = {
    # Route ALL internet traffic through a tailnet exit node (privacy on
    # untrusted wifi). `--exit-node-allow-lan-access` keeps the local LAN
    # (printers, NAS) reachable. Run with no args to see current + choices.
    ts-exit = ''
      switch "$argv[1]"
        case off none clear
          tailscale set --exit-node=
          and echo "tailscale: exit node cleared — direct internet via local link"
        case "" status
          # Read the routing state, not the ExitNodeIP pref. `--exit-node=<name>`
          # resolves the name to a node ID and leaves ExitNodeIP empty, so that
          # pref reports "none" while every packet is going through the tunnel.
          # .ExitNode is the peer actually carrying traffic; .ExitNodeOption is
          # merely one offering to.
          set -l active (tailscale status --json \
            | jq -r '.Peer[] | select(.ExitNode == true) | .HostName + " (" + .TailscaleIPs[0] + ")"')
          if test -z "$active"
            set active none
          end
          echo "current exit-node: $active"
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
