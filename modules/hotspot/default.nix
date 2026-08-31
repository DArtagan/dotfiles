# Share this host's wifi uplink as a WPA2 access point, over the same radio.
#
# Pairs with ./hm.nix (the `hotspot` fish helper). Imported per-host in
# flake.nix. See ./README.md — in particular for why this uses hostapd and
# keeps NetworkManager away from the AP interface entirely.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.hotspot;

  rundir = "/run/hotspot";

  # Everything except the passphrase, which is appended at runtime so it never
  # lands in the world-readable nix store.
  hostapdConf = pkgs.writeText "hostapd.conf" ''
    interface=${cfg.interface}
    driver=nl80211
    ssid=${cfg.ssid}
    country_code=${cfg.countryCode}
    hw_mode=g
    channel=${toString cfg.channel}
    beacon_int=${toString cfg.beaconInterval}
    ieee80211n=1
    wmm_enabled=1
    auth_algs=1
    wpa=2
    wpa_key_mgmt=WPA-PSK
    rsn_pairwise=CCMP
  '';

  setup = pkgs.writeShellApplication {
    name = "hotspot-setup";
    runtimeInputs = [
      pkgs.iw
      pkgs.iproute2
      pkgs.gawk
      pkgs.iptables
      pkgs.procps # sysctl
      config.networking.networkmanager.package
    ];
    text = ''
      ap=${cfg.interface}
      net=${cfg.subnet}

      # Which device holds the uplink is not knowable at build time. Excluding
      # $ap matters on a restart, where the AP vif still exists.
      uplink=$(nmcli -t -f DEVICE,TYPE,STATE device status \
        | awk -F: -v ap="$ap" '$2 == "wifi" && $1 != ap && $3 == "connected" { print $1; exit }')
      if [ -z "$uplink" ]; then
        echo "hotspot: no connected wifi device to share" >&2
        exit 1
      fi
      echo "$uplink" > ${rundir}/uplink

      # A second vif on the uplink's phy. Deliberately not deleted on stop —
      # see the teardown script.
      if [ ! -e "/sys/class/net/$ap" ]; then
        phy=$(cat "/sys/class/net/$uplink/phy80211/name")
        iw phy "$phy" interface add "$ap" type __ap
      fi

      # ath11k rejects a second vif sharing the first one's MAC, so flip the
      # locally-administered bit of the uplink's address.
      base=$(cat "/sys/class/net/$uplink/address")
      first=$(printf '%02x' "$(( 0x$(echo "$base" | cut -d: -f1) ^ 2 ))")
      ip link set "$ap" down
      ip link set "$ap" address "$first:$(echo "$base" | cut -d: -f2-)"
      ip link set "$ap" up
      ip addr flush dev "$ap"
      ip addr add "$net.1/24" dev "$ap"

      umask 077
      { cat ${hostapdConf}; echo "wpa_passphrase=$(cat ${cfg.pskFile})"; } \
        > ${rundir}/hostapd.conf

      # NAT out the uplink, so clients egress behind this host's address and a
      # one-device-at-a-time network still sees one device. -C first because
      # these are appended at runtime and must not stack up across restarts.
      sysctl -qw net.ipv4.ip_forward=1
      iptables -t nat -C POSTROUTING -s "$net.0/24" -o "$uplink" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -s "$net.0/24" -o "$uplink" -j MASQUERADE
      iptables -C FORWARD -i "$ap" -o "$uplink" -j ACCEPT 2>/dev/null \
        || iptables -I FORWARD 1 -i "$ap" -o "$uplink" -j ACCEPT
      iptables -C FORWARD -i "$uplink" -o "$ap" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
        || iptables -I FORWARD 1 -i "$uplink" -o "$ap" -m state --state RELATED,ESTABLISHED -j ACCEPT

      # Uplinks worth sharing are often the ones with a sub-1500 PMTU (in-flight
      # satellite, hotel VPN). Without this, HTTPS to some hosts hangs.
      iptables -t mangle -C FORWARD -o "$uplink" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
        || iptables -t mangle -A FORWARD -o "$uplink" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    '';
  };

  teardown = pkgs.writeShellApplication {
    name = "hotspot-teardown";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iptables
    ];
    text = ''
      ap=${cfg.interface}
      net=${cfg.subnet}
      uplink=$(cat ${rundir}/uplink 2>/dev/null || echo "")

      if [ -n "$uplink" ]; then
        iptables -t nat -D POSTROUTING -s "$net.0/24" -o "$uplink" -j MASQUERADE 2>/dev/null || true
        iptables -D FORWARD -i "$ap" -o "$uplink" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i "$uplink" -o "$ap" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
        iptables -t mangle -D FORWARD -o "$uplink" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
      fi

      # The vif is brought down but NOT deleted. `iw dev <ap> del` resets the
      # ath11k radio, which takes the uplink offline for ~15s — a bad trade
      # every time the hotspot is switched off. An idle, unmanaged, down vif
      # costs one slot in the interface combination and nothing else. To fully
      # release the radio: `sudo iw dev ${cfg.interface} del`.
      if [ -e "/sys/class/net/$ap" ]; then
        ip addr flush dev "$ap" || true
        ip link set "$ap" down || true
      fi
    '';
  };
in
{
  options.my.hotspot = {
    enable = lib.mkEnableOption "sharing the wifi uplink as an access point";

    ssid = lib.mkOption {
      type = lib.types.str;
      example = "steam_powered_internet";
      description = "SSID broadcast by the access point.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "ap0";
      description = ''
        Name of the virtual AP interface added to the uplink's phy.
        NetworkManager is configured to ignore it; see ./README.md.
      '';
    };

    channel = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = ''
        2.4 GHz channel for the AP. Pinned rather than automatic: the uplink's
        channel varies network to network and cannot live in config.
      '';
    };

    beaconInterval = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = ''
        Beacon interval in TU. The radio requires "STA/AP BI must match", so
        this has to equal the upstream AP's. 100 is near-universal; check with
        `iw dev <uplink> scan dump | grep -i "beacon interval"` if the AP
        refuses to start.
      '';
    };

    countryCode = lib.mkOption {
      type = lib.types.str;
      default = "US";
      description = "Regulatory domain advertised by the AP.";
    };

    subnet = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0";
      description = ''
        First three octets of the client subnet. The host takes .1 and clients
        are handed .10-.100.
      '';
    };

    pskFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression ''config.sops.secrets."wifi/hotspot_psk".path'';
      description = ''
        File containing the WPA2 passphrase, read at runtime and appended to
        the generated hostapd config. Point this at a decrypted secret, never
        at a path in the nix store — the store is world-readable.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.iw ];

    # The whole reason this module does not use NetworkManager for the AP:
    # NM hands a wifi interface to wpa_supplicant, which creates a P2P device
    # per interface. The radio allows #{ P2P-device } <= 1 and p2p-dev-<uplink>
    # already exists, so claiming the AP vif restarts the supplicant and takes
    # the uplink down with it. hostapd creates no P2P device.
    networking.networkmanager.unmanaged = [ "interface-name:${cfg.interface}" ];

    networking.firewall.trustedInterfaces = [ cfg.interface ];

    # No wantedBy: started on demand via the `hotspot` helper.
    systemd.services.hotspot = {
      description = "Share the wifi uplink as an access point";
      after = [ "NetworkManager.service" ];
      requires = [ "NetworkManager.service" ];
      wants = [ "hotspot-dnsmasq.service" ];
      before = [ "hotspot-dnsmasq.service" ];
      serviceConfig = {
        Type = "simple";
        RuntimeDirectory = "hotspot";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = lib.getExe setup;
        ExecStart = "${pkgs.hostapd}/bin/hostapd ${rundir}/hostapd.conf";
        ExecStopPost = lib.getExe teardown;
        Restart = "no";
      };
    };

    # DHCP and DNS for clients. Bound to the AP so the two always agree about
    # whether the hotspot is up.
    systemd.services.hotspot-dnsmasq = {
      description = "DHCP/DNS for the wifi hotspot";
      bindsTo = [ "hotspot.service" ];
      after = [ "hotspot.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.dnsmasq}/bin/dnsmasq"
          "--keep-in-foreground"
          "--interface=${cfg.interface}"
          "--bind-interfaces"
          "--except-interface=lo"
          "--listen-address=${cfg.subnet}.1"
          "--dhcp-range=${cfg.subnet}.10,${cfg.subnet}.100,12h"
          "--dhcp-option=3,${cfg.subnet}.1"
          "--dhcp-option=6,${cfg.subnet}.1"
        ];
      };
    };
  };
}
