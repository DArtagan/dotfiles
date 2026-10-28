# pi on Pi Durable: one daemon per host, thin clients

## Opening prompt

> Read `todos/pi-durable.md` and check that its verified facts still hold against
> the pi version nixpkgs now ships. Then do step 1, the headless bridge test: a
> Pi Durable harness with pi-claude-bridge loaded through a shim, running a turn
> with tool calls, surviving a kill mid-tool, and compacting. Report what held
> and what didn't before building anything further. Work in a new repo (or a
> `.worktrees/` branch here for the Nix side), and update the spec as facts change.

Written **2026-10-28**. Nothing has been built. Facts under *What exists* were
read from source that day: pi **v1.4.0** (the tag on GitHub, and the nixpkgs
build), pi-claude-bridge **0.9.3** as built by `pkgs/pi-claude-bridge`. Nothing
was run. Line numbers are for those versions.

## Why

Will's words, 2026-10-28:

- *"I'd like to move in the direction of using Pi Durable, for the purposes of
  abstracting apart the interface and the harness. Eventually allowing me to
  interface from terminal, web, and mobile. And build more isolation around
  agents' environments. Eventually this could become an orchestration platform
  as well."*

## Decided

Will's words, 2026-10-28:

- *"I'm okay with dropping or rebuilding all of the extensions, except for
  pi-claude-bridge - that one's indispensable to my set-up."*
- *"For a first proof-of-concept version, I'd be looking to get to
  as-close-as-possible to the vanilla pi experience/flows, but built on Durable."*
- Asked whether tmux panes could share *"one user-wide service that's running the
  durable pi process and owning the storage"*, and on hearing yes, asked for this
  spec. So: **one daemon per host, owning the storage; every pane is a client.**

Proposed in that conversation and not objected to, but not explicitly signed off:
the build order below, one SQLite storage for all conversations, a Unix socket
for local clients, `/quit` keeping vanilla semantics plus a new `/detach`.
Confirm these when they come up.

## What exists

### Pi Durable is a library, not a mode of pi

- `@earendil-works/pi-durable` shipped with pi 1.0 (2026-10-01), marked
  **experimental: "The API changes without notice between releases."** It is a
  harness (storage, tasks, conversations, extensions, compaction), not an app.
  Announcement: <https://earendil.com/posts/pi-durable>. README and examples:
  `packages/durable/` in <https://github.com/earendil-works/pi>.
- **The coding agent (`pi`) does not use it.** `packages/coding-agent/package.json`
  doesn't depend on it.
- **There is no first-party server or client.** pi 1.2.0 removed "the unreleased
  experimental server, client, and plugin stack" and the `pi-client`,
  `pi-protocol` and `pi-server` packages (coding-agent `CHANGELOG.md`, 1.2.0).
- **Breaking changes land in minor releases.** 1.4.0 removed `TaskRuntime.sleep()`,
  made `checkpointWhen` mandatory on documents, and migrates SQLite storage to a
  schema 1.3.0 can't open (durable `CHANGELOG.md`). Bumping pi means bumping this
  carefully.
- **nixpkgs already builds it.** `nixpkgs#pi-coding-agent` (1.4.0) contains
  `pi-monorepo/node_modules/@earendil-works/{pi-durable,pi-env,pi-ai,pi-tui,chord,gondolin,…}`,
  all 1.4.0 (gondolin 0.12.0). None of it is exposed as a library.

### The v1.0.0 demo: a coding agent on Durable, with pi's TUI

At tag `v1.0.0`, `packages/coding-agent/src/experimental/durable/` held a small
coding agent on Durable (removed in 1.2.0 with the server stack). Files:
`main.ts`, `runtime.ts` (14 KB), `tui.ts` (25 KB), `prompt.ts`, `subagent.ts`,
`sessions.ts`, `harness-setup.ts`, `README.md`. Its README:

- It reused pi's model runtime, auth, settings, system prompt, keybindings,
  theme, and interactive components. The agent was the Harness with Durable's
  built-in `CodingTools`.
- Kill it mid-tool, restart with `--continue`, and the turn finishes: "Nothing in
  the TUI handles recovery; it only renders the conversation view."
- It had streaming, tool output, steer/follow-up/Esc, `/model`, thinking levels,
  `/compact`, subagents with an `/agents` switcher, and a task-graph panel.
- It lacked a session picker, forks and tree navigation, extensions, prompt
  templates, images, and `/login`.
- `runtime.ts` passed pi's `ModelRuntime` to the Harness as `models`, and split
  rendering from control with plain `DurableView` / `DurableController` interfaces.
  That split is where a network transport goes.
- One SQLite file per session, with a lock file to keep a second process out.

### Pieces in pi 1.4.0 the PoC can reuse

- **pi-tui** (`@earendil-works/pi-tui`) is a general terminal UI toolkit: an
  editor, Markdown, select lists, overlays, images. It has no agent dependencies
  (`get-east-asian-width`, `marked`, `marked-cjk-friendly`).
- **The coding agent exports its interactive components "for extensions"**
  (`packages/coding-agent/src/index.ts`, around lines 435–490):
  `AssistantMessageComponent`, `UserMessageComponent`, `ToolExecutionComponent`,
  `BashExecutionComponent`, `CustomEditor`, `FooterComponent`,
  `ModelSelectorComponent`, `SessionSelectorComponent`, `TreeSelectorComponent`,
  `renderDiff`, and the theme functions (`initTheme`, `getMarkdownTheme`, …).
  They take plain pi-ai message types, which Durable stores in its transcript.
  **Not exported:** `createAllToolRenderers` and `WorkingStatusIndicator`, both
  of which the demo used.
- **Also exported:** `ModelRuntime`, `SettingsManager`, `KeybindingsManager`,
  `DefaultResourceLoader`, `loadProjectContextFiles`, `loadSkills`,
  `ExtensionRunner`, `discoverAndLoadExtensions`. These cover loading AGENTS.md,
  skills, settings and keybindings exactly as pi does.
- **Watching:** `Conversation.viewState()` (a Chord replicated state),
  `watch()` (the exact operations of each commit, "small enough to send over a
  socket"), and `watchEvents()` (coding-agent-style events on top of a snapshot).
  Late joiners and reconnects start from a fresh snapshot (durable README,
  "Watching a Conversation", "Agent Events").
- **Chord** (`@earendil-works/chord`) has links over memory, Node IPC and
  WebSocket (`webSocketLink`, `acceptWebSockets`), and its replicated state
  ships to remote viewers as a snapshot plus deltas. It runs in Node and
  browsers. It's the obvious transport, though nothing here has tried it.
- **Isolation, for later:** `@earendil-works/pi-env` runs tools on another
  machine through a small Rust daemon over SSH, while the harness and
  credentials stay local. Gondolin runs QEMU/krun micro-VMs. Durable's `env`
  callback builds an environment per tool call from the conversation, so each
  conversation can get its own sandbox (example `29-sandbox-per-conversation.ts`).

### pi-claude-bridge's dependencies on the coding agent

`pkgs/pi-claude-bridge` 0.9.3 (rev `874fa7c`, with
`multi-session-registration.patch`). Its source is about 4.7k lines of
TypeScript; `src/index.ts` alone is 2,745.

It's an extension factory, `(pi: ExtensionAPI) => void`. From the coding agent
it uses:

- **`pi.registerProvider("claude-bridge", config)`** (`index.ts:2593–2611`).
  `config` is `{ baseUrl, apiKey, api, models, streamSimple }`.
  `ModelRuntime.registerProvider(providerId, config)` takes the same shape
  (`coding-agent/src/core/model-runtime.ts:936`).
- **Nine events:** `session_start`, `session_shutdown`, `session_before_compact`,
  `session_before_tree`, `session_compact`, `session_tree`, `before_agent_start`,
  `agent_start`, `turn_start` (`index.ts:2464–2622`). From their context it reads
  `ctx.sessionManager.getSessionId()`, `ctx.cwd`, `ctx.ui` (only `notify`),
  `ctx.mode`, `ctx.modelRegistry`, `ctx.getSystemPrompt()`, and
  `event.systemPrompt` / `event.systemPromptOptions` (custom prompt, append text,
  context files, skills, sections, selected tools).
- **`pi.registerTool`**, only for AskClaude, which upstream has deprecated. Drop it.
- **Imports:** `buildSessionContext`, `keyHint` and types from
  `@earendil-works/pi-coding-agent`, `Text` from `@earendil-works/pi-tui`, and
  pi-ai. **Its build has none of these:** `package.nix` strips the peer
  dependencies because "pi supplies its own packages … to extensions at load
  time". It ships `src/*.ts`, not JavaScript. A Durable host must resolve those
  imports and load TypeScript itself, either through pi's own extension loader or
  its own module resolution. Not worked out yet.

Behaviour that matters on Durable:

- **Per-session state.** `sharedSessions` (`index.ts:246`) and
  `historyRewrittenBySession` are keyed by the pi session id. The comments say
  one process serves several sessions at once (pi-web; subagents compacting
  while their parent waits). The cwd map (`session-cwd.ts`) exists because a
  multi-session host has a single `process.cwd()`.
- **Prompt capture is the delicate part.** The bridge runs Claude Code with its
  own `claude_code` preset and appends only the portable parts of pi's prompt:
  context files, skills, custom and append text, sections (`index.ts:2054`). To
  find them, it looks up the request's system prompt, exactly, among prompts it
  recorded at `before_agent_start` / `agent_start` / `turn_start`
  (`prompt-capture.ts`, `resolveOrDerive`). A prompt it can't account for
  **throws and fails the turn**, rather than drop instructions or ship pi's
  harness text. A comment at `index.ts:2513–2517` says shipping that text trips
  "the server's third-party plan-eligibility check ('out of extra usage')".
- **Summary calls:** a request with `cacheRetention: "none"` goes to an isolated
  Claude Code process, without touching the session (`index.ts:1775–1780`).
- **Resuming after a restart:** when the last message is a tool result that no
  query in this process was waiting on ("a restart, a crash, a stall"), it
  resumes the saved Claude Code session with `CONTINUE_AFTER_RESUME_PROMPT`
  (`index.ts:1718–1723`).
- **After compaction or tree navigation**, `session_compact` / `session_tree`
  mark the session for a rebuild. Without that, it keeps resuming a Claude Code
  session that no longer matches pi's history (comments around `index.ts:2539–2562`).

### How Durable lines up

- **Session id:** each conversation has a persisted UUIDv7 that Durable sends to
  pi-ai as `sessionId`. It survives reopen, retries, reset, compaction and model
  changes; a fork or child gets a fresh one (durable README, "Persist and
  Resume"). This is the key the bridge needs.
- **Compaction** sends `cacheRetention: "none"` together with the conversation's
  `sessionId` (`durable/src/harness/compaction.ts:177–181`), so it takes the
  bridge's isolated summary path. It runs in the background while the
  conversation continues.
- **Prompt:** built from extension sections and stored as positional system
  entries in the transcript; only what changed is sent again (README, "System
  Prompt"). The `beforeRequest` hook on `GenerationTask` sees the request's
  messages, system entries included, just before the model call
  (`generation.ts:220–231`; type at `types.ts:854`). That is where the host would
  record prompt captures. Unverified: that the string it records equals what the
  bridge's `toBridgeContext` rebuilds from the same transcript.
- **Crash recovery:** a cut-off model request is sent again, with the partial
  answer kept and marked aborted. A cut-off tool call reruns only if declared
  `replay: "safe"`; otherwise the model gets an `interrupted` result. Durable's
  built-in tools are its own (`CodingTools`: read, write, edit, bash), not the
  coding agent's.
- **Tool environment:** `new NodeExecutionEnv({ cwd, shellPath?, shellEnv? })`
  (`durable/src/env/node.ts:621`). `shellEnv` is layered over `process.env`
  (`node.ts:270–281`). The `env` callback receives the conversation id, its `cwd`
  and committed reads, so the environment can come from a per-conversation
  document.
- **Storage:** one process owns a storage, with no locking between processes
  (README, "Storage"). A storage error closes the whole Harness; `harness.closed`
  tells the host to reopen (README, "Errors"). A task cut off by crashes 5 times
  in a row is parked (`settings.restartLimit`).
- **Tool ordering:** `settings.toolExecution: "sequential" | "parallel"`
  replaces `modules/pi/sequential-file-tools.ts`, though it's coarser.

### Prior art, not adopted

[disler/durable-pi](https://github.com/disler/durable-pi) has a per-device
backend (`dpi-backend`, HTTP plus server-sent events, bearer token, one SQLite
file per session plus a catalog), a web hub, a pi-style `dpi-tui` on pi-tui
1.0.3, and a curl API. It is set up for OpenRouter, Node 24, `just` and zsh. Its
API and SDK (`apps/dpi-sdk`) are worth reading for wire-protocol ideas.

## Architecture

```
tmux pane: pi (thin client) ─┐
tmux pane: pi (thin client) ─┼─ Unix socket ($XDG_RUNTIME_DIR) ─┐
later: web / phone ──────────┘   WebSocket on tailscale0, auth ─┤
                                                                 ▼
                    systemd user service (one per host, under home-manager)
                    Harness + SQLite storage (all conversations)
                    ModelRuntime + pi-claude-bridge (through the shim)
                    env(conversation) → NodeExecutionEnv({ cwd, shellEnv })
                    later: pi-env / Gondolin per conversation
```

- **One storage for all conversations** is Durable's native layout: forks and
  subagents just work, and `/resume` lists conversations filtered by cwd. The
  cost: a storage error drops every pane at once until the service restarts and
  Durable resumes. If that's too coarse, fall back to one Harness per session
  file inside the same process (as durable-pi does).
- **Clients never open the storage.** All reads and writes go through the daemon.
- **A systemd `.socket` unit** could start the daemon when the first pane
  connects.

### Wrong turn, corrected

The first plan was one process per pane, with one SQLite file per session (as
the v1.0.0 demo did), so several panes could run pi at once. That works, but it
puts the harness back in the interface process, against the whole point. The
daemon solves multi-pane properly, so per-session files are only a fallback for
isolating failures.

## The bridge shim

Call the bridge's factory with an object standing in for `pi`:

| Bridge calls or waits for | Shim does |
|---|---|
| `registerProvider(id, config)` | `modelRuntime.registerProvider(id, config)`; the Harness gets `models: modelRuntime` |
| `registerTool` (AskClaude) | Ignore. Set `askClaude.enabled: false` for the daemon. |
| `session_start` (reason `new` / `resume` / `fork`) | Fire when a conversation is created, first used after a daemon start, or forked. The `ctx` has `sessionManager.getSessionId()` returning the conversation's provider session id, plus `cwd`, `mode: "tui"`, `ui.notify` sent to attached clients, and `modelRegistry` |
| `before_agent_start` / `agent_start` / `turn_start` | From `beforeRequest`: the rendered system prompt plus its parts (context files, skills, sections) |
| `session_compact` | When a compaction summary is placed |
| `session_tree` | On fork or tree navigation |
| `session_before_compact` / `session_before_tree` | Probably unneeded: the bridge already routes summaries by `cacheRetention`. Check. |
| `session_shutdown` | When the daemon closes |

If the shim can't satisfy the bridge, the fallback is a bridge patch exporting
`streamClaudeAgentSdk` plus the capture and rebuild calls. The repo already
carries one patch to this package.

## Build order

1. **Headless bridge test.** This is the gate; if it fails, nothing after it matters.
   A script: open a Harness on SQLite, with `ModelRuntime`, the shim and
   `CodingTools`. Then:
   - Run a turn with several tool calls on `claude-bridge/claude-opus-5-5`.
   - `kill -9` mid-tool, reopen, `harness.resume()`. The turn should finish
     without Claude Code's session diverging (bridge debug log).
   - Run `compact()` mid-conversation and continue. The next turn should
     rebuild, not resume stale history.
   - Fork and continue both branches.
   - Check that no prompt-capture throw occurs, and that no turn reports
     "out of extra usage".
2. **The daemon and the protocol.** A home-manager user service, a Unix socket,
   and a wire protocol over the view/controller split (try Chord). Pass the
   client's environment through (below).
3. **The TUI client.** Port `tui.ts` from v1.0.0 to Durable 1.4.0. Load settings,
   keybindings and theme with pi's exported managers.
4. **Vanilla parity.** Build in this order:
   - the prompt: pi's system prompt sections, AGENTS.md, and skills (ketch's
     included), from `DefaultResourceLoader` and `loadSkills`
   - `/new`, `/resume` picker, `--continue`
   - `/fork`, `/tree`
   - the footer (tokens, cost, context, quota)
   - tool renderers
   - `!` bash
   - `@file` autocomplete
   - image paste

   Out of scope for the PoC: `/login` (log in with pi itself; credentials are
   shared), loading arbitrary pi extensions, `/share` and `/export`, prompt
   templates.
5. **Packaging.** The app lives in its own repo and is packaged in
   `pkgs/<name>`, pinned to the pi version nixpkgs ships. A module goes under
   `modules/pi/` next to the classic setup, which stays installed throughout.

## Daemon behaviour that differs from vanilla pi

- **Environment.** Vanilla pi's bash inherits the pane's shell: devenv/direnv
  `PATH`, `nix develop`, `SSH_AUTH_SOCK`. A service gets systemd's, which is the
  problem `modules/pi/remote.nix` patches over for agegr.
  - The plan: the client sends its environment on attach, the daemon stores it in
    a conversation document, and `env` passes it as `shellEnv`. Refresh it on
    every attach, so devenv changes take effect.
  - `GIT_CONFIG_GLOBAL` (the agents' git config without difftastic) goes in the
    unit, as `remote.nix` does.
- **SSH agent.** A session given the pane's `SSH_AUTH_SOCK` keeps signing access
  after you detach, while that socket lives. This conflicts with the
  per-terminal approval in `todos/ssh-agent.md`; settle it with that spec.
- **Closing a pane doesn't stop the agent.**
  - Proposed: `/quit` keeps vanilla semantics (it ends the session's running
    turn), `/exit` keeps waiting for the turn as `modules/pi/exit.ts` does, and a
    new `/detach` leaves it running.
  - Decide what Ctrl+C on an empty prompt does. The demo exited at once and left
    the work running.
- **Restarts interrupt every pane.** home-manager restarts a changed user service
  on switch. Durable resumes everything, but bash and other tools not safe to
  rerun come back as "interrupted". Configure the unit so switches don't restart
  it (the exact home-manager setting is unchecked), and restart it deliberately
  when idle.
- **Gained:** two panes on one session both see it live and can both steer it.
- **Resources:** each active turn's Claude Code child process lives in the
  service's cgroup, so a memory limit or restart affects every session.
- **One daemon per host.** The Steam Deck gets its own. Reaching another host's
  sessions comes with the tailnet listener.

## Not checked

- Whether the bridge loads outside pi's extension loader at all (TypeScript
  source, with its `@earendil-works/*` imports supplied by pi).
- Whether the captured system prompt string matches the bridge's `toBridgeContext`.
- How much of the v1.0.0 `tui.ts` / `runtime.ts` still compiles against 1.4.0.
- Chord as the transport: whether `viewState()`'s replicated state can be served
  across a link directly, or needs copying into a Chord `state`.
- Whether Durable's `CodingTools` output renders well in the coding agent's
  `ToolExecutionComponent` without its renderers.
- How the bridge's Claude Code process count and memory scale with many idle
  sessions in one process.

## Done when (PoC)

- `pi` in two tmux panes, in two projects, runs two sessions at once through one
  daemon, with the devenv environment each pane had.
- A claude-bridge turn with tools, interrupted by `systemctl --user restart`,
  finishes after the restart without being asked again.
- The flows used day to day work as in vanilla pi: prompt, steer, follow-up, Esc,
  `/model`, thinking, `/compact`, `/new`, `/resume`, `/fork`, `/tree`, `!`, `@file`.
- Classic `pi` still works alongside it.

When it lands, the setup goes in a module README and `CLAUDE.md` (Modules), then
this file and its entry in `todos/README.md` are deleted. If the bridge test
fails and the project is shelved, record why here instead.
