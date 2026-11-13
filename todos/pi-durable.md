# pi on Pi Durable: packaging and the module

## Opening prompt

> Read `todos/pi-durable.md`, then `~/repositories/pier/todos/poc.md` to see how far
> pier has got. Once pier has a daemon and a client worth running daily, package it
> as `pkgs/pier` and add a home-manager module under `modules/pi/`, next to the
> classic setup. Work on a `.worktrees/` branch, and update both specs as facts change.

The implementation lives in its own repo: **pier**, at `~/repositories/pier`, on
GitHub as `DArtagan/pier` (since 2026-11-03, with CI and release-please; releases are
tags only, as dotfiles packages it). Its `todos/poc.md` carries the project spec that
started here: the why, Will's decisions, the build order, and what's been verified.
This file keeps only what lands in dotfiles: build step 5.

Status, 2026-11-12: step 1, the headless bridge test, **passed** again on pi 1.5.2 with
pi-claude-bridge 0.12.0 (42/42), as it did on 1.4.0 and 0.9.3 on 2026-10-29.
pi-claude-bridge runs on a Durable Harness through a shim, survives `kill -9` and Esc
mid-tool, compacts, and forks, with no prompt-capture failures and no "out of extra
usage". Steps 2–4 (daemon, TUI client, vanilla parity) are next, in pier. They wait on
Will: the wire format and transport (pier's `todos/wire-format.md`), and two new
questions at the top of pier's `todos/poc.md` (carry on, or follow Earendil's own
"Pi Roam"; keep the bridge, or Earendil's pi-claude-code). Nothing here has started.

## Facts for packaging

- **nixpkgs builds Durable but doesn't expose it.** `nixpkgs#pi-coding-agent`
  contains `lib/node_modules/pi-monorepo/node_modules/@earendil-works/{pi-durable,pi-ai,pi-tui,chord,pi-env,gondolin,…}`.
  pier takes them from npm instead, pinned exactly in its `package.json`, so
  `buildNpmPackage` from its lockfile is the straightforward route.
- **pier's pi doesn't follow nixpkgs'** (changed 2026-11-12). pier pins 1.5.2;
  nixos-unstable has 1.5.0. Nothing ties them together, since pier builds from its own
  lockfile, and pi-claude-bridge 0.12.0 needs pi 1.5.1 or newer. The earlier rule (keep
  them equal) had no real reason behind it. What they do share is `~/.pi/agent`.
- **pier depends on pi-claude-bridge 0.12.0 from npm**, not `pkgs/pi-claude-bridge`
  (0.11.0 here, for nixpkgs' pi 1.5.0, with `multi-session-registration.patch`, which
  only matters when several copies of the bridge load in one process; pier loads
  one). If pier ever needs a patched bridge, point it at the package here instead.
- **The bridge ships TypeScript**, and pier loads it with jiti at runtime, as pi does
  (`src/bridge/load.ts`). Node won't strip types under `node_modules`. pier's own code
  runs on Node 24's type stripping, with no build step.
- **The bridge still reads `~/.pi/agent/claude-bridge.json`** for
  `pathToClaudeCodeExecutable` (set in `modules/pi/default.nix`). Its debug log
  defaults to `~/.pi/agent/claude-bridge.log`, which classic pi shares; give the
  daemon its own with `CLAUDE_BRIDGE_DEBUG_PATH`. Since 0.10 it also keeps
  per-session state in `~/.pi/agent/claude-bridge/sessions/`, keyed by session id, so
  pier's conversations and classic pi's sessions never meet there.

## The module

- **A systemd user service per host**, under home-manager, owning one SQLite storage.
  Optionally a `.socket` unit, so the first pane starts it.
- **`GIT_CONFIG_GLOBAL`** pointing at the agents' git config (`agentGitConfigPath`
  in `modules/pi/default.nix`), as the `pi` wrapper and `remote.nix` do.
- **`KillMode=control-group`** (systemd's default), and nothing weaker. Durable runs
  each tool in a process group of its own, so even killing the daemon's whole process
  group left an interrupted `sleep 20; echo done > slept.txt` running, and it wrote its
  file after the agent was told it was interrupted (pier's gate, 2026-11-12). Only the
  cgroup kill reaps tools.
- **Don't restart on switch.** A restart interrupts every pane, and tools not safe to
  rerun come back "interrupted". Find the home-manager setting that keeps a changed
  user service running (unchecked), and restart it deliberately when idle.
- **Classic pi stays installed** throughout, and keeps working alongside.

When pier's PoC lands and is packaged, the setup goes in a module README and
`CLAUDE.md` (Modules), and this file and its entry in `todos/README.md` are deleted.
