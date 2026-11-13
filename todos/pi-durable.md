# pi on Pi Durable: packaging and the module

## Opening prompt

> Read `todos/pi-durable.md`, then `~/repositories/pier/todos/poc.md`, "The thin
> slice". pier has a daemon and a client; package it as `pkgs/pier` (it needs a build
> step first; see below) and add a home-manager module under `modules/pi/`, next to
> the classic setup. Work on a `.worktrees/` branch, and update both specs as facts
> change.

The implementation lives in its own repo: **pier**, at `~/repositories/pier`, on
GitHub as `DArtagan/pier` (since 2026-11-03, with CI and release-please; releases are
tags only, as dotfiles packages it). Its `todos/poc.md` carries the project spec that
started here: the why, Will's decisions, the build order, and what's been verified.
This file keeps only what lands in dotfiles: build step 5.

Status, 2026-11-13. Will chose, that day, Earendil's **pi-claude-code** over
pi-claude-bridge for pier (it passed the same gate, 39/39), and a **very thin slice**
while Earendil's Pi Roam takes shape. The slice is built in pier: `pier daemon` (one
Harness, one SQLite file, a Unix socket) and a minimal terminal client, `pier`. It's
checked offline and by hand with real Claude, a restart mid-tool included. Classic pi
here keeps pi-claude-bridge; nothing in this repo has changed for pier yet.

## Facts for packaging

- **nixpkgs builds Durable but doesn't expose it.** `nixpkgs#pi-coding-agent`
  contains `lib/node_modules/pi-monorepo/node_modules/@earendil-works/{pi-durable,pi-ai,pi-tui,chord,pi-env,gondolin,…}`.
  pier takes them from npm instead, pinned exactly in its `package.json`, so
  `buildNpmPackage` from its lockfile is the straightforward route.
- **pier's pi doesn't follow nixpkgs'** (changed 2026-11-12). pier pins 1.5.2;
  nixos-unstable has 1.5.0. Nothing ties them together, since pier builds from its own
  lockfile. What they share is `~/.pi/agent` (settings, credentials).
- **pier talks to Claude through pi-claude-code** (`@earendil-works/pi-claude-code`),
  pinned in its lockfile to a commit as a GitHub tarball (`codeload.github.com`): no
  git or SSH at build time, and `fetchNpmDeps` should take it like any tarball
  (unchecked). It runs `claude` from the PATH, or `PI_CLAUDE_CODE_COMMAND`, on Claude
  Code's own login; the unit should set `PI_CLAUDE_CODE_COMMAND` to
  `lib.getExe pkgs.claude-code`, as `piClaudeBridgeSettings` does for the bridge.
- **pier needs a build step before it can be packaged.** It runs its TypeScript with
  Node's type stripping, which Node refuses under `node_modules`, where
  `buildNpmPackage` installs a package. Bundle it with esbuild (or compile with `tsc`)
  in pier first. pi-claude-code also ships TypeScript and is loaded with jiti, which
  works anywhere.
- **Its paths:** the socket is `$XDG_RUNTIME_DIR/pier/pier.sock` and the storage
  `$XDG_STATE_HOME/pier/pier.sqlite` (`~/.local/state/pier`), both private. The
  daemon runs in its state directory, because Claude Code tells the model about its
  working directory; don't set `WorkingDirectory` to a project.

## The module

- **A systemd user service per host**, under home-manager, owning one SQLite storage:
  `pier daemon`, which exits cleanly on SIGTERM. A `.socket` unit would need the daemon
  to take an inherited socket, which it doesn't yet.
- **PATH.** Each conversation's tools get the environment of the pane that last
  attached, so the unit's own PATH matters only to the daemon itself and to `claude`.
- **`GIT_CONFIG_GLOBAL`** pointing at the agents' git config (`agentGitConfigPath`
  in `modules/pi/default.nix`), as the `pi` wrapper and `remote.nix` do.
- **`KillMode=control-group`** (systemd's default), and nothing weaker. Durable runs
  each tool in a process group of its own, so even killing the daemon's whole process
  group left an interrupted `sleep 20; echo done > slept.txt` running, and it wrote its
  file after the agent was told it was interrupted (pier's gate, 2026-11-12). Only the
  cgroup kill reaps tools. pi-claude-code spawns Claude Code detached too.
- **Don't restart on switch.** A restart interrupts every pane, and tools not safe to
  rerun come back "interrupted". Find the home-manager setting that keeps a changed
  user service running (unchecked), and restart it deliberately when idle.
- **Classic pi stays installed** throughout, and keeps working alongside.

When pier's PoC lands and is packaged, the setup goes in a module README and
`CLAUDE.md` (Modules), and this file and its entry in `todos/README.md` are deleted.
