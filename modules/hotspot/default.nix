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

  # The invariant part. hw_mode, channel and the passphrase are appended at
  # runtime: the first two are not knowable until the uplink is up, and the
  # passphrase must never land in the world-readable nix store.
  hostapdConf = pkgs.writeText "hostapd.conf" ''
    interface=${cfg.interface}
    driver=nl80211
    ssid=${cfg.ssid}
    country_code=${cfg.countryCode}
    beacon_int=${toString cfg.beaconInterval}
    ieee80211n=1
    # 802.11d advertises the regulatory domain. 802.11h carries DFS and transmit
    # power control, and is what makes the radar-shared 5 GHz channels usable in
    # AP mode at all -- without it hostapd rejects them outright.
    ieee80211d=1
    ieee80211h=1
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

            # One radio, one useful channel. This phy's interface combination permits
            # "#channels <= 2", so an AP on a channel other than the uplink's does
            # come up -- and the radio then time-slices between the two, which
            # collapses throughput. Measured in that state: ~110ms RTT to a client at
            # -26 dBm, and clients unable to load anything at all. So follow the
            # uplink rather than pinning a channel.
            # Mirror the uplink's whole channel geometry -- primary, width and centre
            # -- not just its channel number. Matching the channel alone is not
            # enough: the radio holds exactly one channel context, so it narrows to
            # the AP's width while the STA keeps framing transmissions for the wider
            # one. Nothing it sends is acknowledged, rate control collapses to the
            # 6 Mbit/s basic rate, and the uplink stops passing traffic entirely.
            # Measured, with a 20 MHz AP against a 40 MHz uplink on one channel:
            # tx 300 Mbit/s -> 6.0 Mbit/s, 100% loss to the gateway, while rx was
            # untouched. Matching the width restored it completely.
            #
            # Parse by field position: matching a bare number would also catch the
            # "1" in the literal "center1:".
            read -r freq width cf1 <<<"$(iw dev "$uplink" info | awk '
              $1 == "channel" {
                gsub("[()]", "", $3); f = $3
                for (i = 1; i <= NF; i++) {
                  if ($i == "width:")   w  = $(i+1)
                  if ($i == "center1:") c1 = $(i+1)
                }
                print f, w, c1; exit
              }')"

            extra=""
            if [ -z "$freq" ]; then
              echo "hotspot: cannot read $uplink's channel, falling back to ${toString cfg.channel}" >&2
              mode=g
              chan=${toString cfg.channel}
            else
              if [ "$freq" -ge 5000 ]; then
                mode=a
                chan=$(( (freq - 5000) / 5 ))
              else
                mode=g
                chan=$(( (freq - 2407) / 5 ))
              fi

              case "$width" in
                20 | "") ;;
                40 | 80 | 160)
                  # Which half of the wide block holds the primary decides whether the
                  # HT40 secondary sits above or below it. (width / 2 - 10) is the
                  # distance from the centre down to the block's first 20 MHz slot, so
                  # one formula covers 40, 80 and 160.
                  slot=$(( (freq - (cf1 - (width / 2 - 10))) / 20 ))
                  if [ $(( slot % 2 )) -eq 0 ]; then
                    extra="ht_capab=[HT40+]"
                  else
                    extra="ht_capab=[HT40-]"
                  fi
                  # Above 40 MHz the width is carried by VHT rather than HT.
                  if [ "$width" = 80 ] || [ "$width" = 160 ]; then
                    if [ "$width" = 80 ]; then vht=1; else vht=2; fi
                    extra="$extra
      ieee80211ac=1
      vht_oper_chwidth=$vht
      vht_oper_centr_freq_seg0_idx=$(( (cf1 - 5000) / 5 ))"
                  fi
                  ;;
                *)
                  # Starting anyway would mean a mismatched width, which does not
                  # degrade the uplink so much as switch it off. Refuse instead.
                  echo "hotspot: uplink is $width MHz wide, which this module cannot mirror." >&2
                  echo "hotspot: refusing to start -- an AP of a different width on the" >&2
                  echo "hotspot: uplink's channel takes this host off the network." >&2
                  exit 1
                  ;;
              esac
            fi

            # 5 GHz channels 52-144 are shared with radar, so an AP there must sit
            # through a 60s channel-availability check before it may transmit. Already
            # being associated to another AP on that channel does not exempt us: the
            # kernel grants no concurrent-operation relaxation here, so hostapd runs
            # the full CAC. Worth the wait -- the alternative is the time-slicing
            # above, which is permanently broken rather than briefly late.
            if [ "$mode" = a ] && [ "$chan" -ge 52 ] && [ "$chan" -le 144 ]; then
              echo "hotspot: uplink is on DFS channel $chan; the AP needs ~60s to start" >&2
            fi

            umask 077
            {
              cat ${hostapdConf}
              echo "hw_mode=$mode"
              echo "channel=$chan"
              if [ -n "$extra" ]; then printf '%s\n' "$extra"; fi
              echo "wpa_passphrase=$(cat ${cfg.pskFile})"
            } > ${rundir}/hostapd.conf

            # NAT out the uplink, so clients egress behind this host's address and a
            # one-device-at-a-time network still sees one device. -C first because
            # these are appended at runtime and must not stack up across restarts.
            # Remember the prior value so teardown can put it back. RuntimeDirectory is
            # recreated on every start, so this is always this run's own reading.
            cat /proc/sys/net/ipv4/ip_forward > ${rundir}/ip_forward
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

            # --- The `ts-exit` path -------------------------------------------------
            #
            # With an exit node set, table 52 gains a default route and the ip rule
            # "from all lookup 52" catches forwarded packets too, so client traffic
            # leaves via tailscale0 rather than $uplink. None of the rules above match
            # that path. All three below are scoped by -o tailscale0, so they are inert
            # whenever the exit node is off and need no toggling alongside it.

            # Clients would otherwise reach the exit node still carrying their
            # $net.0/24 source, which is not in the tailnet's ACL, so it is dropped
            # inside tailscaled with no ICMP back -- the client just sees a black hole.
            # SNAT to this host's tailnet address, which the ACL does accept.
            #
            # The ! -d exclusion keeps this to internet egress. Un-SNATted tailnet
            # traffic still fails the far-side ACL check exactly as it does today, so
            # guest isolation does not depend on this rule surviving.
            iptables -t nat -C POSTROUTING -s "$net.0/24" -o tailscale0 ! -d 100.64.0.0/10 -j MASQUERADE 2>/dev/null \
              || iptables -t nat -A POSTROUTING -s "$net.0/24" -o tailscale0 ! -d 100.64.0.0/10 -j MASQUERADE

            # tailscale0 is MTU 1280. Same reasoning as the $uplink clamp above.
            iptables -t mangle -C FORWARD -o tailscale0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
              || iptables -t mangle -A FORWARD -o tailscale0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

            # Guests get the internet through the tunnel, not the tailnet behind it.
            #
            # In mangle because mangle/FORWARD is evaluated before filter/FORWARD, so
            # this cannot be short-circuited by ts-forward's catch-all
            # "-o tailscale0 -j ACCEPT" -- whose jump returns to position 1 of FORWARD
            # every time tailscaled restarts and re-adds its hooks. For a deny rule,
            # position is the whole rule. It also sits before nat/POSTROUTING, so it
            # matches the original client source rather than the SNATted one.
            #
            # DROP rather than REJECT: REJECT is a filter-table target. Clients see a
            # timeout rather than an immediate refusal.
            #
            # This only stops guests riding *this host's* tailnet membership. A guest
            # running its own tailscale tunnels to its peers inside UDP to a public
            # endpoint, which is opaque here and rightly an ACL question instead.
            for dest in 100.64.0.0/10 192.168.0.0/24; do
              iptables -t mangle -C FORWARD -i "$ap" -o tailscale0 -d "$dest" -j DROP 2>/dev/null \
                || iptables -t mangle -A FORWARD -i "$ap" -o tailscale0 -d "$dest" -j DROP
            done
    '';
  };

  teardown = pkgs.writeShellApplication {
    name = "hotspot-teardown";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iptables
      pkgs.procps # sysctl
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

      # The tunnel-path rules key on tailscale0, not $uplink, so they come out
      # even when the uplink record is missing.
      iptables -t nat -D POSTROUTING -s "$net.0/24" -o tailscale0 ! -d 100.64.0.0/10 -j MASQUERADE 2>/dev/null || true
      iptables -t mangle -D FORWARD -o tailscale0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
      for dest in 100.64.0.0/10 192.168.0.0/24; do
        iptables -t mangle -D FORWARD -i "$ap" -o tailscale0 -d "$dest" -j DROP 2>/dev/null || true
      done

      # ip_forward is global: tailscale (subnet routing), podman and NM's shared
      # mode all set it too. Only revert it if this service is what turned it on.
      if [ "$(cat ${rundir}/ip_forward 2>/dev/null || echo 1)" = "0" ]; then
        sysctl -qw net.ipv4.ip_forward=0
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

  # Keeps the AP on the uplink's channel for as long as the hotspot runs.
  #
  # Polls rather than subscribing to `iw event`. A tick costs ~6ms of CPU
  # against a hostapd already beaconing ten times a second, so the power
  # difference is noise; and an event stream would still need a periodic
  # backstop plus a fresh read of the channel, so it buys latency we do not
  # need and no simplicity at all.
  chanfollow = pkgs.writeShellApplication {
    name = "hotspot-chanfollow";
    runtimeInputs = [
      pkgs.iw
      pkgs.gawk
      pkgs.systemd
    ];
    text = ''
      ap=${cfg.interface}
      uplink=$(cat ${rundir}/uplink 2>/dev/null || echo "")
      if [ -z "$uplink" ]; then
        echo "hotspot: no uplink recorded, nothing to follow" >&2
        exit 1
      fi

      poll=20         # seconds between checks
      settle=30       # the uplink must hold a new channel this long before we act
      cooldown=180    # minimum seconds between two switches
      max_switches=4  # per hour, then stop following and say so

      # Switch history has to outlive this process: following means restarting
      # hotspot.service, which takes this service down with it, so an in-process
      # counter would reset on exactly the event it is meant to be counting.
      # StateDirectory survives a stop; RuntimeDirectory does not.
      history=''${STATE_DIRECTORY:-/var/lib/hotspot}/switches

      # "<primary>/<width>/<centre>" for either vif -- `iw dev <if> info` prints
      # the same channel line for a STA and an AP. Empty when the interface is
      # not on a channel: uplink disconnected, or AP not yet enabled.
      #
      # The whole geometry, not just the channel number. An AP whose width
      # differs from the uplink's takes the uplink off the network just as
      # surely as one on a different channel, so a width change alone is a
      # reason to follow.
      #
      # Read back from the driver rather than from the config we generated:
      # hostapd relocates itself when it detects radar, and catching that move
      # is half the point of this service.
      geom() {
        iw dev "$1" info 2>/dev/null | awk '
          $1 == "channel" {
            gsub("[()]", "", $3); f = $3
            for (i = 1; i <= NF; i++) {
              if ($i == "width:")   w  = $(i+1)
              if ($i == "center1:") c1 = $(i+1)
            }
            print f "/" w "/" c1; exit
          }'
      }

      candidate=""
      candidate_since=0
      last_switch=0

      while :; do
        sleep "$poll"
        now=$(date +%s)

        up=$(geom "$uplink")
        if [ -z "$up" ]; then
          # Uplink down. Leave the AP exactly where it is -- clients keep their
          # association, and the uplink usually comes back on its own.
          candidate=""
          continue
        fi

        cur=$(geom "$ap")
        if [ -z "$cur" ] || [ "$cur" = "$up" ]; then
          candidate=""
          continue
        fi

        # Require the same new geometry twice over $settle, so something seen
        # mid-roam does not trigger a restart we immediately have to undo.
        if [ "$candidate" != "$up" ]; then
          candidate=$up
          candidate_since=$now
          continue
        fi
        [ $(( now - candidate_since )) -ge "$settle" ] || continue
        [ $(( now - last_switch )) -ge "$cooldown" ] || continue

        count=0
        if [ -f "$history" ]; then
          awk -v now="$now" '(now - $1) < 3600' "$history" > "$history.tmp"
          mv "$history.tmp" "$history"
          count=$(wc -l < "$history")
        fi

        # A uplink flapping between two DFS channels would otherwise pin the
        # hotspot in a permanent 60s CAC cycle, never actually serving. Stop
        # acting, keep running, and resume once the hour rolls forward.
        if [ "$count" -ge "$max_switches" ]; then
          echo "hotspot: uplink has changed channel $count times in the last hour; not following" >&2
          candidate=""
          continue
        fi

        echo "$now" >> "$history"
        last_switch=$now
        echo "hotspot: uplink is now $up, AP is on $cur; restarting to follow" >&2

        # --no-block is load-bearing. BindsTo means this restart stops us, and a
        # blocking systemctl would be killed partway through its own request.
        # The queued job lives inside systemd and outlives this process.
        systemctl --no-block restart hotspot.service
        exit 0
      done
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
        Fallback 2.4 GHz channel, used only when the uplink's own channel cannot
        be read. Normally the AP follows the uplink: the two share one radio,
        and putting them on different channels forces it to time-slice, which
        leaves the hotspot connected but unable to pass traffic.
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

    followUplinkChannel = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Restart the AP when the uplink changes channel, so the two stay
        together. They share one radio, and letting them drift apart leaves the
        hotspot associated but unable to pass any traffic. Costs a brief outage
        per move, or ~60s when the new channel is one of the radar-shared ones.
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

    systemd.services = {
      # No wantedBy: started on demand via the `hotspot` helper.
      hotspot = {
        description = "Share the wifi uplink as an access point";
        after = [ "NetworkManager.service" ];
        requires = [ "NetworkManager.service" ];
        wants = [
          "hotspot-dnsmasq.service"
        ]
        ++ lib.optional cfg.followUplinkChannel "hotspot-chanfollow.service";
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

      # Keeps the AP and the uplink on one channel. Bound to the AP, so it only
      # runs while there is something to follow.
      hotspot-chanfollow = lib.mkIf cfg.followUplinkChannel {
        description = "Keep the access point on the uplink's channel";
        bindsTo = [ "hotspot.service" ];
        after = [ "hotspot.service" ];
        serviceConfig = {
          Type = "simple";
          StateDirectory = "hotspot";
          ExecStart = lib.getExe chanfollow;
          # on-failure, not always: the clean exit after requesting a restart
          # must not race the restart job already on its way to stop us.
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # DHCP and DNS for clients. Bound to the AP so the two always agree about
      # whether the hotspot is up.
      hotspot-dnsmasq = {
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
  };
}
