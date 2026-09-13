# Home-manager half of the hotspot module: user-facing CLI helper.
#
# Pairs with ./default.nix (the NixOS service). Imported per-user in flake.nix
# on hosts that share their wifi uplink. See ./README.md.
_: {
  programs.fish.functions = {
    # Share this machine's wifi uplink as an access point, on the same radio.
    # Useful where only one device may be online at a time (hotel, plane):
    # clients NAT out behind this host, so the network still sees one device.
    hotspot = ''
      switch "$argv[1]"
        case on start up
          # Stamped before the start so the AP-ENABLED search below cannot
          # match a previous run's.
          set -l t0 (date '+%Y-%m-%d %H:%M:%S')
          sudo systemctl start hotspot
          or return 1
          # hotspot-setup's notices go to the journal, never to this terminal.
          # The DFS one earns its place: on a radar-shared channel the AP must
          # listen for 60s before it may transmit, and Type=simple returns as
          # soon as hostapd execs — so without this a silent minute looks
          # exactly like a hang.
          journalctl -u hotspot --since "$t0" -o cat 2>/dev/null | grep "^hotspot:"
          # Wait for hostapd itself to say AP-ENABLED. The interface is not a
          # usable signal here: mac80211 sets the channel context up front, so
          # `iw dev ap0 info` already reports a channel all through the CAC.
          set -l waited 0
          while not journalctl -u hotspot --since "$t0" -o cat 2>/dev/null | grep -q AP-ENABLED
            if not systemctl is-active -q hotspot
              echo "hotspot: service stopped before the AP came up — see 'journalctl -u hotspot'" >&2
              return 1
            end
            if test $waited -ge 90
              echo "hotspot: no AP-ENABLED after $waited""s — see 'journalctl -u hotspot'" >&2
              return 1
            end
            sleep 2
            set waited (math $waited + 2)
          end
          # Width, not just channel: a mismatch there is what takes the uplink
          # off the network, so it is worth being able to eyeball it.
          set -l where (iw dev ap0 info | awk '$1 == "channel" { for (i = 1; i <= NF; i++) if ($i == "width:") w = $(i+1); print "channel " $2 " @ " w " MHz" }')
          echo "hotspot: up after $waited""s on $where — clients get 10.42.0.0/24, NAT'd out the uplink"
        case off stop down
          sudo systemctl stop hotspot
          and echo "hotspot: down — NAT removed, ap0 left down (`sudo iw dev ap0 del` frees the radio)"
        case "" status
          echo "hostapd: "(systemctl is-active hotspot)"  dnsmasq: "(systemctl is-active hotspot-dnsmasq)
          echo
          echo "radio (uplink and AP must be on the SAME channel):"
          iw dev
          echo
          echo "devices (the AP interface should read 'unmanaged'):"
          nmcli device status
          echo
          echo "clients:"
          ip neigh show dev ap0 2>/dev/null; or echo "  none"
        case '*'
          echo "usage: hotspot [on|off|status]" >&2
          return 1
      end
    '';
  };
}
