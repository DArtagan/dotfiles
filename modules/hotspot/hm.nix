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
          sudo systemctl start hotspot
          and echo "hotspot: up — clients get 10.42.0.0/24, NAT'd out the uplink"
        case off stop down
          sudo systemctl stop hotspot
          and echo "hotspot: down — NAT removed, ap0 left down (`sudo iw dev ap0 del` frees the radio)"
        case "" status
          echo "hostapd: "(systemctl is-active hotspot)"  dnsmasq: "(systemctl is-active hotspot-dnsmasq)
          echo
          echo "radio (uplink and AP must be on separate channels):"
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
