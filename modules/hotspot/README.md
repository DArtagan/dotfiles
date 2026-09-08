# Hotspot module

Shares this host's **wifi uplink** back out as a WPA2 access point, using the
**same radio**. The case it exists for: a network that only lets one device
online at a time (plane, hotel, conference). Clients are NAT'd behind this
host's address, so the network still sees exactly one device.

```
phone ──wifi──> ap0 (AP)   ┐
                           ├─ one phy, one channel ─ NAT ─> uplink SSID ─> internet
laptop ─wifi──> ap0        ┘   wlo1 (STA, wherever the uplink is)
```

## Whether your radio can do this

This is not universally possible. One STA and one AP on the same phy requires
the driver to advertise an interface combination that permits it:

```console
$ iw phy phy0 info | grep -A2 "valid interface combinations"
        valid interface combinations:
                 * #{ managed } <= 2, #{ AP, P2P-client, P2P-GO } <= 16, ...
                   total <= 16, #channels <= 1, STA/AP BI must match, ...

                 * #{ managed } <= 2, #{ AP, P2P-client, P2P-GO } <= 16, ...
                   total <= 4, #channels <= 2, STA/AP BI must match
```

The second line is the one that matters: one `managed` + one `AP`, `total <= 4`,
**`#channels <= 2`**. That output is from a Steam Deck (Qualcomm QCNFA765 /
WCN6855, `ath11k_pci`).

Read `#channels <= 2` as a warning rather than a feature. It is why the AP
*starts* on a channel other than the uplink's — not why doing so is survivable.
ath11k satisfies a two-channel request by time-slicing the single radio between
them, and the result is a hotspot that associates, hands out DHCP leases,
resolves DNS, and then moves essentially no traffic. Measured on this card with
`ap0` on channel 6 while `wlo1` sat on channel 60:

| Measurement | Result |
|---|---|
| RTT to a client at −26 dBm | 75–154 ms (should be 1–3 ms) |
| `ap0` counters over 5 s | RX +71 packets, TX +11 |
| What the client sees | nothing loads |

So the module follows the uplink's channel rather than pinning one — see
[Channel following](#channel-following). A card offering only `#channels <= 1`
would have forced that behaviour from the start.

`STA/AP BI must match` is a live constraint: if the upstream AP uses a beacon
interval other than 100 TU, activation fails and NetworkManager has no knob for
it. The fallback there is `services.hostapd` with an explicit `beacon_int`.

## Why hostapd and not NetworkManager

The obvious implementation — `nmcli device wifi hotspot` on the AP vif, or a
declarative NM profile with `ipv4.method = "shared"` — **does not work here**,
and fails in a way that takes the uplink down with it.

NetworkManager hands every wifi interface it manages to `wpa_supplicant`, which
creates one **P2P device per interface**. The combination above allows
`#{ P2P-device } <= 1`, and `p2p-dev-<uplink>` already exists. Claiming the AP
vif therefore makes NM log

```
device (p2p-dev-ap0): error setting IPv4 forwarding to '0': Resource temporarily unavailable
device (wlo1): Couldn't initialize supplicant interface: Name owner lost
```

— `wpa_supplicant` is restarted, and the uplink drops for ~15 s along with it.

hostapd creates no P2P device, so the module runs hostapd directly and sets
`networking.networkmanager.unmanaged = [ "interface-name:ap0" ]` so NM never
touches the vif at all. Verified working: `ap0` serving clients while `wlo1`
stayed associated, both on one channel. (An earlier revision of this file
recorded the split-channel case as working — it associates, but see the table
above for what it actually does.)

## Options

Set per host in `flake.nix`, all in [`default.nix`](./default.nix):

| Option           | Default      | Notes |
|------------------|--------------|-------|
| `enable`         | `false`      | |
| `ssid`           | —            | Broadcast SSID. |
| `interface`      | `"ap0"`      | The virtual AP vif, added to the uplink's phy. |
| `followUplinkChannel` | `true`  | Restart the AP when the uplink changes channel. |
| `channel`        | `6`          | Fallback only, used when the uplink's channel can't be read. |
| `beaconInterval` | `100`        | TU. Must equal the upstream AP's — see below. |
| `countryCode`    | `"US"`       | Regulatory domain. |
| `subnet`         | `"10.42.0"`  | Host takes `.1`, clients get `.10`–`.100`. |
| `pskFile`        | —            | File holding the bare passphrase. Must be a decrypted secret, **not** a store path. |

The uplink interface is *not* an option: it's discovered at runtime as whichever
wifi device currently holds the connection, which is not knowable at build time.

## Why these choices

- **The AP follows the uplink's channel.** Not a preference: one radio serving
  two channels time-slices, and the hotspot stops passing traffic. See
  [Channel following](#channel-following).
- **`beacon_int` is an option.** The combination says `STA/AP BI must match`. If
  the upstream AP uses something other than 100 TU, hostapd will not reach
  `AP-ENABLED`. Check with
  `iw dev <uplink> scan dump | grep -i "beacon interval"`.
- **The MAC is the uplink's with the locally-administered bit flipped.** ath11k
  rejects a second vif that duplicates the first one's address.
- **The passphrase is appended to the config at runtime.** The static part of
  `hostapd.conf` is a store file; the PSK is read from `pskFile` into
  `/run/hotspot/hostapd.conf` (mode 0700) so it never enters the nix store.
- **An MSS clamp on forwarded SYNs.** The uplinks worth sharing are exactly the
  ones with a sub-1500 PMTU — in-flight satellite, hotel VPN. Without it, HTTPS
  to some hosts hangs while everything else looks fine.
- **Separate NAT and MSS rules for the tunnel path.** With a tailscale exit node
  set, `ip rule ... lookup 52` catches forwarded packets too, so client traffic
  leaves via `tailscale0` rather than the uplink and none of the uplink-scoped
  rules match it. Clients are SNATted to this host's tailnet address — the exit
  node's ACL drops their `10.42.0.x` source silently otherwise — clamped again
  for the 1280-byte tunnel MTU, and blocked from the tailnet itself, so guests
  get the internet through the tunnel rather than the network behind it.
- **`ip_forward` is restored, but only if we set it.** It is a global knob that
  tailscale (subnet routing), podman and NM's shared mode also drive. Setup
  records its prior value in `/run/hotspot/ip_forward`; teardown reverts to `0`
  only if it read `0` there, so switching the hotspot off never breaks another
  service's forwarding. If the record is missing, teardown leaves it alone.
- **WPA2, not WPA3.** This exists to get devices on without fuss.

## Channel following

`hw_mode` and `channel` are not in the store config. `hotspot-setup` reads the
uplink's frequency with `iw dev <uplink> link` and appends both when the service
starts, and `hotspot-chanfollow` restarts the AP when the uplink later moves.

Following matters because a one-shot read goes stale in ordinary use:

- **Roaming.** One SSID across many APs on different channels — hotels,
  conferences — with NetworkManager moving the uplink between them.
- **Radar.** On a radar-shared channel the upstream AP must vacate within 10 s
  of a detection. Moving is the designed behaviour there, not a fault.
- **Our own evacuation.** `ieee80211h` makes this host a DFS master too, so
  hostapd relocates `ap0` by itself if it detects radar — almost certainly not
  to wherever the uplink went.

The follower polls every 20 s (~6 ms of CPU per tick, against a hostapd already
beaconing ten times a second, so the power cost is noise). It requires a new
channel to hold for 30 s before acting, waits 180 s between switches, and stops
after 4 switches in an hour — an uplink flapping between two DFS channels would
otherwise pin the hotspot in a permanent CAC cycle where it never serves at all.
It logs when it stops, and resumes once the hour rolls forward. Set
`followUplinkChannel = false` to disable it.

It restarts rather than sending a Channel Switch Announcement. `hostapd_cli
chan_switch` would keep clients associated through a move, but it cannot switch
onto a channel that has not been cleared by a CAC — exactly the case that
matters here.

### DFS channels

5 GHz channels 52–64 and 100–144 are shared with radar, so an AP there must
listen for 60 s before it may transmit: a Channel Availability Check. Measured
on this card:

| Configuration | Result |
|---|---|
| DFS channel, no `ieee80211h` | `not allowed for AP mode, flags: 0x979 RADAR` — refused in 2 s |
| DFS channel, `ieee80211d=1` + `ieee80211h=1` | `DFS-CAC-START cac_time=60s` → `DFS-CAC-COMPLETED success=1` → `AP-ENABLED` at 60 s |

Already being associated to another AP on that channel earns **no** exemption.
It is tempting to reason that the upstream AP is the DFS master and has done the
check already, but the kernel grants no concurrent-operation relaxation here and
hostapd sits through the full 60 s itself.

So `ieee80211d` and `ieee80211h` are always on, and the hotspot simply takes
~60 s to come up on a DFS channel. Setup says which case you are in:

```
hotspot: uplink is on DFS channel 60; the AP needs ~60s to start
```

There is deliberately no fallback to a non-DFS channel: 60 s late beats the
permanent time-slicing that pinning a channel would cost.

Which channels this card treats as DFS:

```console
$ iw phy phy0 info | grep -B1 "radar detection"
```

## Usage

```console
hotspot on       # add the vif, start hostapd + dnsmasq + NAT
hotspot off      # stop the AP, remove NAT, leave the vif down
hotspot status   # service state + `nmcli device status` + `iw dev`
```

After `hotspot on`, both interfaces should be present **on the same channel**,
and the uplink must still be connected:

```console
$ iw dev                                    # wlo1 (managed) AND ap0 (AP)
$ nmcli -f GENERAL.STATE device show wlo1   # still 100 (connected)
$ ip -br addr show ap0                      # 10.42.0.1/24
$ iw dev ap0 info | grep channel            # these two must agree
$ iw dev wlo1 link | grep freq
$ journalctl -u hotspot | grep AP-ENABLED
```

`systemctl is-active hotspot` is not sufficient evidence the AP is serving: the
unit is `Type=simple`, so it reports active whenever the hostapd process is
alive, including when the interface never came up. `ip -br link show ap0` must
read `UP`, and a repeating `Failed to set beacon parameters` in the journal means
it did not.

If hostapd never reaches `AP-ENABLED`, check `beaconInterval` first. On a DFS
channel, expect a 60 s wait before it does — that is the CAC, not a hang.

### `hotspot off` leaves the vif in place

Teardown brings `ap0` down but does **not** delete it. `iw dev ap0 del` resets
the ath11k radio and takes the uplink offline for ~15 s, which is a bad trade
every time the hotspot is switched off. An idle, unmanaged, down vif costs one
slot in the interface combination and nothing else. To fully release the radio:

```console
sudo iw dev ap0 del     # expect the uplink to drop briefly
```

## Secret

`pskFile` is read at service start and appended to the generated
`hostapd.conf`, so it wants the bare passphrase — a plain `sops.secrets` path,
no templating:

```nix
sops.secrets."wifi/hotspot_psk" = { };

my.hotspot.pskFile = config.sops.secrets."wifi/hotspot_psk".path;
```

Adding the secret needs a TTY (the SSH key is passphrase-protected):

```console
sops set hosts/<host>/secrets.yaml '["wifi"]["hotspot_psk"]' '"<passphrase>"'
```

Note that sops authenticates each value against its **key path**, so a secret
written to the wrong place cannot be fixed by re-indenting the encrypted file —
`sops unset` it and set it again at the right path.
