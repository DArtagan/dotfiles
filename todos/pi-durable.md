# pi on Pi Durable: packaging and the module

## Opening prompt

> Read `todos/pi-durable.md`, then `~/repositories/pier/todos/poc.md` to see how far
> pier has got. Once pier has a daemon and a client worth running daily, package it
> as `pkgs/pier` and add a home-manager module under `modules/pi/`, next to the
> classic setup. Work on a `.worktrees/` branch, and update both specs as facts change.

The implementation lives in its own repo: **pier**, at `~/repositories/pier` on
thenixbeast. As of 2026-10-29 it's git only, with no remote (Will: *"keep the git repo
local for now"*). Its `todos/poc.md` carries the project spec that started here: the
why, Will's decisions, the build order, and what's been verified. This file keeps only
what lands in dotfiles: build step 5.

Status, 2026-10-29: step 1, the headless bridge test, **passed** (33/33 checks).
pi-claude-bridge runs on a Durable Harness through a shim, survives `kill -9`
mid-tool, compacts, and forks, with no prompt-capture failures and no "out of extra
usage". Steps 2–4 (daemon, TUI client, vanilla parity) are next, in pier. Nothing here
has started.

## Facts for packaging

- **nixpkgs builds Durable but doesn't expose it.** `nixpkgs#pi-coding-agent` (1.4.0)
  contains `lib/node_modules/pi-monorepo/node_modules/@earendil-works/{pi-durable,pi-ai,pi-tui,chord,pi-env,gondolin,…}`,
  all 1.4.0 (gondolin 0.12.0). pier takes them from npm instead, pinned exactly to
  1.4.0 in its `package.json`, so `buildNpmPackage` from its lockfile is the
  straightforward route. Keep the pin equal to nixpkgs' pi: Durable is experimental,
  breaking changes land in minor releases, and 1.4.0 migrated SQLite storage to a
  schema 1.3.0 can't open.
- **pier depends on pi-claude-bridge 0.9.3 from npm**, not `pkgs/pi-claude-bridge`.
  Same source, minus `multi-session-registration.patch`, which only matters when
  several copies of the bridge load in one process. pier loads one. If pier ever needs
  a patched bridge, point it at the package here instead.
- **The bridge ships TypeScript**, and pier loads it with jiti at runtime, as pi does
  (`src/bridge/load.ts`). Node won't strip types under `node_modules`. pier's own code
  runs on Node 24's type stripping, with no build step.
- **The bridge still reads `~/.pi/agent/claude-bridge.json`** for
  `pathToClaudeCodeExecutable` (set in `modules/pi/default.nix`). Its debug log
  defaults to `~/.pi/agent/claude-bridge.log`, which classic pi shares; give the
  daemon its own with `CLAUDE_BRIDGE_DEBUG_PATH`.

## The module

- **A systemd user service per host**, under home-manager, owning one SQLite storage.
  Optionally a `.socket` unit, so the first pane starts it.
- **`GIT_CONFIG_GLOBAL`** pointing at the agents' git config (`agentGitConfigPath`
  in `modules/pi/default.nix`), as the `pi` wrapper and `remote.nix` do.
- **`KillMode=control-group`** (systemd's default): the gate's crash test killed the
  host's whole process group. Killing only the daemon would orphan Claude Code and the
  tools' children, and an interrupted `sleep; echo` would still write its file.
- **Don't restart on switch.** A restart interrupts every pane, and tools not safe to
  rerun come back "interrupted". Find the home-manager setting that keeps a changed
  user service running (unchecked), and restart it deliberately when idle.
- **Classic pi stays installed** throughout, and keeps working alongside.

When pier's PoC lands and is packaged, the setup goes in a module README and
`CLAUDE.md` (Modules), and this file and its entry in `todos/README.md` are deleted.
