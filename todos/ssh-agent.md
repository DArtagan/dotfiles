# One SSH agent, unlocked per terminal session

## Opening prompt

> On thenixbeast, every `eval (ssh-agent -c)` starts another agent that is never
> stopped. Read `todos/ssh-agent.md`, check that its verified facts still hold,
> then move SSH onto 1Password's agent as it describes: local terminals approve
> per session, SSH from the steamdeck forwards its agent, SSH from the phone
> falls back to a per-session agent with the sops key. Work on a branch in
> `.worktrees/`, and retire the spec when it lands.

Written **2026-10-21**. Nothing has been built. The facts under *What exists*
were checked on thenixbeast and the steamdeck's evaluated config that day; the
1Password behaviour comes from its docs, not from trying it.

## Decided

Will's words, 2026-10-21:

- *"I'm not sure I necessarily want SSH keys loaded on start-up for every
  terminal, but maybe? Having some degree of security consciousness and control
  is also appealing to me."*
- The requirement, after hearing the options: *"one SSH agent"*, and *"I must
  type my password and unlock the key for any new terminal session to connect
  to it."*
- *"I'm usually forwarding in from my steamdeck, very occasionally my phone."*
- *"I don't want to implement this right now"*: hence this spec.

The approach below (1Password, forwarding from the steamdeck, a fallback for the
phone) was proposed in that conversation and not objected to, but Will has not
explicitly signed off on it. Confirm before building.

## What exists

Verified 2026-10-21 on thenixbeast unless noted.

- **Agents leak.** 22 `ssh-agent -c` processes were running, one per past
  `eval`, with their sockets in `~/.ssh/agent/` (OpenSSH 10.5's default place
  for them). Closing a terminal does not stop its agent.
- **A gcr agent runs but nothing uses it.** `services.gnome.gcr-ssh-agent.enable`
  evaluates to `true` on both thenixbeast and the steamdeck. It comes in with
  `gnome.gnome-keyring.enable` (`hosts/thenixbeast/default.nix`, there for
  1Password's 2FA) and with GNOME on the steamdeck. It listens on
  `/run/user/1001/gcr/ssh`, but `SSH_AUTH_SOCK` was unset in the session checked,
  so it went unused.
- `programs.ssh.startAgent` is `false` on both hosts.
- **`~/.ssh/id_ed25519` is passphrase-protected** and placed by sops
  (`users/will/ssh_private_key` in `hosts/thenixbeast/secrets.yaml`). The
  steamdeck has its own key the same way (`willy@steamdeck`, authorized on
  thenixbeast).
- **1Password is on both hosts** (`programs._1password-gui` in `configuration.nix`,
  `polkitPolicyOwners` per host). Its SSH agent has not been switched on.

Not checked: everything `id_ed25519` is authorized on beyond GitHub; whether
tmux is used over SSH; how 1Password counts Alacritty windows (below).

## Why 1Password, and what was rejected

The thing that rules most options out is pi. **An agent never gives out the key,
but any process that can reach its socket can sign with it**, so a pi session
can `git push` or SSH to the steamdeck or mini-nas without anyone noticing.
Will's requirement means a session must get nothing until he unlocks it there.

| Option | Why not |
|---|---|
| A per-session `eval (ssh-agent -c)` (today) | Meets the requirement, but it's many agents, and they leak. |
| One OpenSSH agent, `SSH_AUTH_SOCK` exported everywhere, `AddKeysToAgent` | Once loaded, every terminal and pi session can use the key without asking. |
| One OpenSSH agent, not exported, joined per session by an `ssh-on` fish function | Was proposed. Joining is only a convention: OpenSSH's agent accepts any process running as Will, so a process that finds the socket can use it. Will then asked for enforcement. |
| `ssh-add -x` / `-X` (lock and unlock the agent) | Locks the whole agent. Unlocking it in one terminal unlocks it for every terminal. |
| gcr-ssh-agent with the passphrase stored in the login keyring | The least control of all: the key works whenever Will is logged in. |
| A proxy of our own in front of `ssh-agent` that checks callers' sessions (`SO_PEERCRED`) | Rebuilds what 1Password already does, less well. |
| A FIDO2 key (`ed25519-sk`) | Needs hardware Will has not mentioned having. |

**1Password's agent finds out which process is calling.** With *Settings →
Developer → "Ask approval for each new: application and terminal session"*, each
new terminal session has to be approved (with the 1Password password or system
authentication) before it can use a key. Programs it starts, such as pi, inherit
the approval. *"Remember key approval"* sets how long an approval lasts. Sources:
[authorization](https://www.1password.dev/ssh/agent/authorization.md),
[security model](https://developer.1password.com/docs/ssh/agent/security).

A caveat on "enforced": 1Password works out the caller from the process tree, as
the same user. It is a much higher bar than OpenSSH's, but no agent fully
isolates processes that run as the same user.

## Remote sessions

**From the steamdeck: forward its agent.** 1Password supports this
([forwarding](https://developer.1password.com/docs/ssh/agent/forwarding)). The
prompt shows on the steamdeck, where Will is, and the key never has to be on
thenixbeast. Consequences:

- Approval is for the steamdeck's one `ssh` process, so **every shell and pi
  session inside one connection shares one approval**. A new connection asks
  again.
- A shell under tmux keeps the socket of the connection that started it, which
  stops working at logout. If tmux is in use, point a fixed `~/.ssh/agent.sock`
  symlink at the current socket on each login.
- Expected, not checked: the prompt does not show in Game Mode. A terminal means
  Desktop Mode anyway.

**From the phone: a per-session OpenSSH agent with the sops key.** The phone can't
run 1Password's agent. Keep `id_ed25519` from sops for this alone. An SSH login
without a forwarded agent gets an agent of its own, the passphrase is typed into
it, and it stops at logout. That still means typing the password once per
session.

**Browser sessions (pi-web, Pi Remote Control)** run as systemd services, with no
SSH connection to forward through. 1Password sees each as its own application,
so its prompt would come up on thenixbeast's desktop, out of sight. Out of scope
here. If pi needs to push from them, the idea floated was a narrowly scoped
GitHub deploy key; it has not been discussed further.

## Likely approach

- **Keys.** Will makes a **new** key in 1Password and adds its public key
  wherever `id_ed25519` is authorized. Keeping the two keys separate means either
  can be revoked without the other. This step is Will's, in the 1Password app,
  on both hosts: turn the SSH agent on, and set "application and terminal
  session".
- **thenixbeast, fish** picks `SSH_AUTH_SOCK` for each session:
  - local: `~/.1password/agent.sock`
  - SSH with a forwarded agent: leave the forwarded socket alone
  - SSH with none (the phone): an agent for that session, started when first
    needed, not at login, and killed on `fish_exit`
- **Do not set `IdentityAgent` in thenixbeast's SSH config.** It overrides
  `SSH_AUTH_SOCK` and would bypass the forwarded agent.
- **The steamdeck's SSH config**: `IdentityAgent ~/.1password/agent.sock`, and
  `ForwardAgent yes` for thenixbeast only. Check which key it then offers when
  logging into thenixbeast, since the 1Password key and `willy@steamdeck` would
  both be available.
- Set `services.gnome.gcr-ssh-agent.enable = false` on thenixbeast, so nothing
  else offers to hold the key. Optional on the steamdeck.
- Once the new setup works, stop the leaked agents (`pkill -u will ssh-agent`)
  and empty `~/.ssh/agent/`.
- Probably a `modules/ssh-agent/` with a README, since the reasoning above is
  worth keeping next to the config.

## To check while building

- How 1Password counts Alacritty windows. Its docs speak of terminal *tabs*.
  Alacritty has none, so each window should count as its own session, but that
  is a guess.
- That a pi session started from an approved terminal is covered by the
  approval, and one started elsewhere gets a prompt.

## Done when

- A new local terminal can't use any key until it is approved in 1Password, and
  `ssh -T git@github.com` works after approving.
- An SSH login from the steamdeck with forwarding prompts on the steamdeck, and
  `git push` from thenixbeast then works in that session.
- An SSH login without forwarding asks for `id_ed25519`'s passphrase once and
  leaves no agent running after logout.
- `pgrep -c ssh-agent` stays at the number of open no-forwarding SSH sessions,
  not one per terminal ever opened.

When this lands, record the setup in `CLAUDE.md` (under Modules) and the new
module's README, then delete this file and its entry in `todos/README.md`.
