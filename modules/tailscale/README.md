# Tailscale / Headscale module

Connects each host to our **self-hosted Headscale** control plane and pins the
settings that must never drift. Roaming-specific behaviour (exit nodes, subnet
routes) is left as *runtime* toggles, on purpose — see [Declarative vs.
runtime](#declarative-vs-runtime-state) below.

- **Control server:** `https://headscale.immortalkeep.com`
- **Headscale config (source of truth):** `~/repositories/vulcanus-proxmox`
  → `kubernetes/apps/headscale/headscale-config-map.yaml`
- **MagicDNS domain:** `forge.local` (every node is `<hostname>.forge.local`)

## What this module pins (declarative invariants)

One option, in [`default.nix`](./default.nix), set per host in `flake.nix`:

| Option     | Default                          | Why it's an option |
|------------|----------------------------------|--------------------|
| `operator` | `null` (set to `will` / `willy`) | The username genuinely differs per host. Lets that user run `tailscale up` / `tailscale set` (and `ts-exit`) without `sudo`. |

Everything else is a **literal in the script**. Each has one value that works
here, so a knob would only offer a way to break it:

| Flag | Value | What another value breaks |
|------|-------|---------------------------|
| `--login-server`  | `https://headscale.immortalkeep.com` | A bare `tailscale up` targets Tailscale's SaaS coordinator instead of ours. |
| `--accept-dns`    | `true` | `*.forge.local` goes `NXDOMAIN`; MagicDNS is the only thing serving it. The resolvers Headscale advertises are public, so there is no black-hole risk to hedge against. |
| `--accept-routes` | `true` | `*.immortalkeep.com` stops resolving away from the LAN — `vulcanus`' `192.168.0.0/24` is the only path to CoreDNS (`192.168.0.202`) and the internal ingress (`192.168.0.203`). Safe on-LAN: Tailscale won't install a route matching the host's own subnet. |

The `tailscale-autoconnect` oneshot applies all of these, on every rebuild and
reboot. It **does not** use a pre-auth key — see
[Bootstrapping](#bootstrapping-a-new-host).

## Bootstrapping a new host

There is **no `--authkey`** by design: a reusable Headscale pre-auth key is a
single point of failure for the entire tailnet, so we register interactively.

On a fresh machine, after the first rebuild:

```bash
sudo tailscale up \
  --login-server https://headscale.immortalkeep.com \
  --accept-dns=true \
  --accept-routes=true \
  --operator=$USER
# then follow the printed URL, or register the node from the Headscale host:
#   headscale nodes register --user <user> --key <nodekey-from-url>
```

Once registered, prefs persist in `/var/lib/tailscale`, and the autoconnect
unit's bare-ish `up` keeps them across reboots.

> If `tailscale up` complains it "requires mentioning all non-default flags"
> (e.g. `--exit-node`), a stale pref is set. Add `--reset` to start clean. See
> [Gotchas](#gotchas).

## Runtime toggles (roaming)

Defined as fish helpers in `home.nix`. They use `tailscale set`, so they apply
live **and work even when fully black-holed** (local daemon calls, no network):

```bash
ts-exit <node>|off|status        # route ALL traffic via an exit node (+ LAN access)
```

- `ts-exit` — full-tunnel through a chosen exit node for privacy on untrusted
  wifi. Clears with `ts-exit off`.

## Declarative vs. runtime state

Deliberate split — don't "fix" it by making everything declarative:

- **Declarative (this module):** login server, `accept-dns`, `accept-routes`,
  operator. Properties of *the tailnet*, so they are identical on every deploy
  — which is why only the operator username is an option at all. The autoconnect
  unit reasserts them on every rebuild and reboot, via `tailscale set` on hosts
  that are already registered and `tailscale up` on those that are not.
- **Runtime (`ts-exit`, persisted in `/var/lib/tailscale`):** exit node. A
  property of *where the laptop currently is*, so intentionally imperative,
  surviving reboots ("persist last state").

Because the unit reasserts these, a manual `tailscale set` of any of them lasts
only until the next rebuild or reboot. For a captive portal, use `tailscale
down` rather than turning `accept-dns` off — see [Gotchas](#gotchas).

## Gotchas

- **Exit nodes fail closed.** If a selected exit node goes offline, or you change
  networks while one is set, *all* traffic black-holes until you clear it —
  reboots re-apply it. Recovery: `ts-exit off`.
- **`*.forge.local` won't resolve → `NXDOMAIN`.** Almost always `accept-dns` got
  turned off. Check `tailscale dns status` (look for "Tailscale DNS: disabled")
  and run `tailscale set --accept-dns=true`.
- **Captive-portal wifi.** `override_local_dns: true` sends DNS to public
  resolvers, which portals may block pre-auth. Fix: **disable Tailscale
  entirely** (`sudo tailscale down`) to get through the portal, then bring it
  back up — do *not* leave `accept-dns` off.
- **MagicDNS resolves offline peers.** A name resolving (`getent hosts …`) does
  not mean the host is up *or reachable* — MagicDNS answers from the netmap
  regardless. Confirm reachability separately with `tailscale ping <host>`. (A
  jetKVM like `jetkvm-mini-nas` can be up while its host is down — or the host
  can be flapping via the deadlock above while its name still resolves.)
- **WireGuard fallback (`wg0`).** A separate, plain WireGuard tunnel provides an
  out-of-band path to one network for when Headscale itself is down. It is *not*
  Tailscale; don't confuse `wg0` routes with `tailscale0`.
- **A remote NAT'd node gets stuck offline and won't self-heal** (shows
  `offline`/DERP-only from peers; on the box, `PollNetMap … context deadline
  exceeded` and `getent hosts headscale.immortalkeep.com` times out). This is a
  **DNS circular-dependency deadlock**, not a per-node fault: with
  `override_local_dns: true`, resolving `headscale.immortalkeep.com` was routed
  to internal resolvers that are *only reachable over the tailnet* — so reaching
  the control server required the tailnet, and the tailnet required the control
  server. Any netmap blip then became permanent. Fixed server-side (2026-07-07,
  `vulcanus-proxmox` commit `26cabb6`) by a more-specific split-DNS route that
  resolves the control host via public DNS (`headscale.immortalkeep.com →
  1.1.1.1, 1.0.0.1`; longest-suffix match wins over the `immortalkeep.com`
  split). Nodes heal on their next poll — **except one already stuck**, which
  needs a one-time nudge to break the deadlock: `tailscale set --accept-dns=false`
  (falls back to the LAN resolver, which resolves the control host publicly),
  wait for it to reconnect, then `tailscale set --accept-dns=true`. That
  momentary `false` is a deliberate recovery step — leave it back at `true`.

## Diagnostics cheat sheet

```bash
tailscale debug prefs | jq '{RouteAll, ExitNodeID, ExitNodeIP, CorpDNS}'  # exit node / accept-routes / accept-dns
tailscale dns status                                                       # is Tailscale DNS enabled? split routes?
tailscale status                                                           # peers, online/offline, exit-node offers
ip route get <ip>                                                          # which interface/tunnel is used
getent hosts headscale.immortalkeep.com                                    # control host must resolve WITHOUT the tailnet (times out = DNS deadlock)
journalctl -u tailscaled | grep -i pollnetmap                              # "context deadline exceeded" = can't reach control plane
```
