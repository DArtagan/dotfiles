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

Set in [`default.nix`](./default.nix), overridable per host in `flake.nix` via
`my.tailscale.*`:

| Option        | Default                              | Why it's pinned |
|---------------|--------------------------------------|-----------------|
| `loginServer` | `https://headscale.immortalkeep.com` | A bare `tailscale up` would otherwise target Tailscale's SaaS coordinator, not ours. |
| `acceptDns`   | `true`                               | **Required.** Headscale serves `*.forge.local` via MagicDNS. With `--accept-dns=false`, those names fail with `NXDOMAIN`. The advertised resolvers are public/reachable, so this is not a black-hole risk. |
| `operator`    | `null` (set to `will` / `willy`)     | Lets that user run `tailscale up` / `tailscale set` (and the `ts-*` helpers) without `sudo`. |

The `tailscale-autoconnect` oneshot applies these on a fresh `tailscale up`. It
**does not** use a pre-auth key — see [Bootstrapping](#bootstrapping-a-new-host).

## Bootstrapping a new host

There is **no `--authkey`** by design: a reusable Headscale pre-auth key is a
single point of failure for the entire tailnet, so we register interactively.

On a fresh machine, after the first rebuild:

```bash
sudo tailscale up \
  --login-server https://headscale.immortalkeep.com \
  --accept-dns=true \
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
ts-routes on|off|toggle|status   # accept tailnet subnet routes (remote LAN access)
ts-exit <node>|off|status        # route ALL traffic via an exit node (+ LAN access)
```

- `ts-routes` — turn **on** to reach subnets a peer advertises (e.g. a remote
  LAN); **off** when you're on that LAN directly.
- `ts-exit` — full-tunnel through a chosen exit node for privacy on untrusted
  wifi. Clears with `ts-exit off`.

## Declarative vs. runtime state

Deliberate split — don't "fix" it by making everything declarative:

- **Declarative (this module):** login server, `accept-dns`, operator. These are
  properties of *the tailnet* and should be identical on every deploy.
- **Runtime (`ts-*` helpers, persisted in `/var/lib/tailscale`):** exit node and
  subnet-route acceptance. These are properties of *where the laptop currently
  is*, so they're intentionally imperative and survive reboots ("persist last
  state").

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
  not mean the host is up. `mini-nas` has been powered off with only its jetKVM
  (`jetkvm-mini-nas`) reachable — the name still resolves.
- **WireGuard fallback (`wg0`).** A separate, plain WireGuard tunnel provides an
  out-of-band path to one network for when Headscale itself is down. It is *not*
  Tailscale; don't confuse `wg0` routes with `tailscale0`.

## Diagnostics cheat sheet

```bash
tailscale debug prefs | jq '{RouteAll, ExitNodeID, ExitNodeIP, CorpDNS}'  # exit node / accept-routes / accept-dns
tailscale dns status                                                       # is Tailscale DNS enabled? split routes?
tailscale status                                                           # peers, online/offline, exit-node offers
ip route get <ip>                                                          # which interface/tunnel is used
```
