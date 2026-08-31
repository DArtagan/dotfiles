# Hotspot module

Shares this host's **wifi uplink** back out as a WPA2 access point, using the
**same radio**. The case it exists for: a network that only lets one device
online at a time (plane, hotel, conference). Clients are NAT'd behind this
host's address, so the network still sees exactly one device.

```
phone ──wifi──> ap0 (AP, 2.4 GHz)  ┐
                                   ├─ same phy ─ NAT ─> uplink SSID ─> internet
laptop ─wifi──> ap0                ┘   wlo1 (STA, whatever band the uplink uses)
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
                   total <= 3, #channels <= 2, STA/AP BI must match
```

The second line is the one that matters: one `managed` + one `AP`, `total <= 3`,
**`#channels <= 2`** — the AP may sit on a different channel from the uplink.
That output is from a Steam Deck (Qualcomm QCNFA765 / WCN6855, `ath11k_pci`).
If your card only offers `#channels <= 1`, the AP is forced onto the uplink's
channel, which changes network to network and cannot be pinned in config.

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
touches the vif at all. Verified working: `ap0` on channel 6 (2437 MHz) serving
clients while `wlo1` stayed associated on channel 157 (5785 MHz).

## Options

Set per host in `flake.nix`, all in [`default.nix`](./default.nix):

| Option           | Default      | Notes |
|------------------|--------------|-------|
| `enable`         | `false`      | |
| `ssid`           | —            | Broadcast SSID. |
| `interface`      | `"ap0"`      | The virtual AP vif, added to the uplink's phy. |
| `channel`        | `6`          | 2.4 GHz. Pinned deliberately — see below. |
| `beaconInterval` | `100`        | TU. Must equal the upstream AP's — see below. |
| `countryCode`    | `"US"`       | Regulatory domain. |
| `subnet`         | `"10.42.0"`  | Host takes `.1`, clients get `.10`–`.100`. |
| `pskFile`        | —            | File holding the bare passphrase. Must be a decrypted secret, **not** a store path. |

The uplink interface is *not* an option: it's discovered at runtime as whichever
wifi device currently holds the connection, which is not knowable at build time.

## Why these choices

- **2.4 GHz, fixed channel.** Uses the two-channel combination, avoids DFS, and
  every client supports it. If throughput is poor, the alternative is to match
  the uplink's channel exactly (one-channel combination, no band splitting) —
  but that channel varies per network, so it can't live in config.
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
- **WPA2, not WPA3.** This exists to get devices on without fuss.

## Usage

```console
hotspot on       # add the vif, start hostapd + dnsmasq + NAT
hotspot off      # stop the AP, remove NAT, leave the vif down
hotspot status   # service state + `nmcli device status` + `iw dev`
```

After `hotspot on`, both interfaces should be present, on different channels,
and the uplink must still be connected:

```console
$ iw dev                                    # wlo1 (managed) AND ap0 (AP)
$ nmcli -f GENERAL.STATE device show wlo1   # still 100 (connected)
$ ip -br addr show ap0                      # 10.42.0.1/24
$ journalctl -u hotspot | grep AP-ENABLED
```

If hostapd never reaches `AP-ENABLED`, check `beaconInterval` first.

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
