# Home-manager half of the tailscale module: user-facing CLI helpers and the
# Taildrop inbox.
#
# Pairs with ./default.nix (the NixOS service). Imported per-user in flake.nix
# on hosts that manage tailscale declaratively. The helpers only need the
# `tailscale` CLI and `jq` in PATH; both halves of Taildrop need the caller to
# be tailscale's `--operator`, which ./default.nix already pins. See ./README.md.
{ lib, pkgs, ... }:
let
  # Taildrop's receive half. Incoming files queue in *this node's* inbox and
  # stay there until something moves them out, so with nothing running this
  # loop, a file sent from the phone simply never appears.
  taildrop-inbox = pkgs.writeShellApplication {
    name = "taildrop-inbox";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.libnotify
    ];
    text = ''
      dir="$HOME/Downloads/taildrop"
      mkdir -p "$dir"
      while true; do
        # --wait blocks while the inbox is empty, so this is event-driven, not
        # a poll. A failure here is a tailscaled restart or a dead network,
        # never a lost file: the inbox lives in /var/lib/tailscale and outlives
        # both. --conflict=rename because the default (skip) leaves a duplicate
        # sitting in the inbox, where it would be re-reported on every wakeup.
        if out=$(tailscale file get --wait --verbose --conflict=rename "$dir" 2>&1); then
          # notify-send bodies are parsed as Pango markup, so a filename
          # containing & or <> would mangle or drop the notification.
          body=$(printf '%s' "$out" | tail -n 5 | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
          # Losing the notification (no daemon, no session bus) must not kill
          # the loop -- the file already landed.
          notify-send "Taildrop" "$body" || true
        else
          # Say why. Without this the failure is invisible: the loop retries
          # every 5s, the unit still reports active, and nothing reaches the
          # journal -- so a wrong operator or an unwritable inbox looks
          # exactly like an idle, healthy wait.
          printf 'taildrop-inbox: %s\n' "$out" >&2
          sleep 5
        fi
      done
    '';
  };
in
{
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

    # Send files over Taildrop. The peer must be online -- Taildrop is
    # peer-to-peer and does not queue anything server-side.
    ts-send = ''
      if test (count $argv) -lt 2
        echo "usage: ts-send <file>... <host>"
        echo
        echo "targets:"
        tailscale file cp --targets
        return 1
      end
      set -l target $argv[-1]
      set -l files $argv[1..-2]
      # The peer goes last, which is easy to forget. Check it against the real
      # target list rather than the filesystem: `test -e` would reject a
      # perfectly good peer whenever a file of the same name sits in the
      # current directory -- and this repo has hosts/thenixbeast and
      # hosts/steamdeck, which are exactly the names one sends to.
      set -l targets (tailscale file cp --targets 2>/dev/null | awk '{print $1; print $2}')
      if test (count $targets) -gt 0; and not contains -- "$target" $targets
        echo "ts-send: '$target' is not a taildrop target" >&2
        echo "targets:" >&2
        tailscale file cp --targets >&2
        return 1
      end
      # `tailscale file cp` rejects directories -- but only when it reaches
      # one, after any files before it have already gone over. Check up front
      # so the send is all-or-nothing.
      for f in $files
        if test -d "$f"
          echo "ts-send: '$f' is a directory; taildrop sends files only" >&2
          echo "         tar czf - '$f' | tailscale file cp --name "(basename $f)".tar.gz - $target:" >&2
          return 1
        end
      end
      tailscale file cp $files "$target:"
      and echo "taildrop: sent "(count $files)" file(s) to $target"
    '';
  };

  systemd.user.services.taildrop-inbox = {
    Unit.Description = "Move incoming Taildrop files into ~/Downloads/taildrop";
    # default.target, not graphical-session.target: receiving files has nothing
    # to do with a compositor being up.
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = lib.getExe taildrop-inbox;
      Restart = "always";
      RestartSec = 5;
    };
  };
}
