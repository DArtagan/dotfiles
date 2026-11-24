# pi module

Installs [pi](https://pi.dev) and merges the keys we manage into its config
(`~/.pi/agent/settings.json`, `~/.pi/agent/claude-bridge.json`). pi writes its
own runtime state into the same files, so they are merged on each switch rather
than symlinked; see `lib/merge-json-into.nix`.

- **Model provider:** [`pi-claude-bridge`](https://github.com/elidickinson/pi-claude-bridge),
  which runs Claude Code (via the Agent SDK) on the Claude subscription. Packaged in
  `pkgs/pi-claude-bridge` to carry local patches, and loaded from the store.
  Its AskClaude tool, which let other providers' models hand work to Claude Code,
  moved to a separate package in 0.11.0 and isn't installed.
- **Plan quotas:** [pi-quotas](https://github.com/latentminds-ai/pi-quotas), packaged
  in `pkgs/pi-quotas`. Shows the Claude plan's 5h/7d windows in the footer, plus
  `/quotas` and near-limit warnings. For claude-bridge models, the bridge passes on
  the usage Claude Code reports with each response, as Anthropic's rate-limit
  headers, and a local patch to pi-quotas reads them, so nothing polls Anthropic
  and no login is read. The windows appear after the first claude-bridge response
  in each pi process, under "Claude Code" in `/quotas` and `/claude-bridge:quotas`.
- **Web access:** [ketch](https://ketch.run), from nixpkgs, with its skill and a
  wrapper added in `pkgs/ketch`. See below.
- **Google Calendar:** read-only, through [gog](https://gogcli.sh) (`google.nix`).
  See below.
- **Todoist:** Doist's `td` CLI, with its skill added in `pkgs/todoist-cli`. See
  below.
- **Tools' skills** (`tools.nix`): ketch, gog and Todoist's `td` each ship their agent
  skills in `share/skills/<pname>/<skill>`, the layout nixpkgs settled on
  ([#547426](https://github.com/NixOS/nixpkgs/issues/547426)) and its
  `installAgentSkills` hook writes. pi's settings list those directories in `skills`;
  pier lists the same ones itself (below, "pier"). Nothing is linked into
  `~/.pi/agent/skills`.
- **Tool calls in order:** a local extension (`sequential-file-tools.ts`). pi runs a
  message's tool calls in parallel, so a `bash` call could run before the write or
  edit it was batched with had landed; the extension makes such a batch run one call
  at a time. pier doesn't need it: its daemon runs every batch in order.
- **Asking instead of guessing:**
  [rpiv-ask-user-question](https://github.com/juicesharp/rpiv-mono/tree/main/packages/rpiv-ask-user-question),
  packaged in `pkgs/rpiv-ask-user-question` from its npm release. Adds an
  `ask_user_question` tool, which opens a dialog of up to four multiple-choice
  questions (each with a free-text row) below the transcript; `Ctrl+]` shrinks it
  to one line. Optional config: `~/.config/rpiv-ask-user-question/config.json`.
- **Observability:** [pine-of-glass](https://github.com/tmustier/pine-of-glass),
  packaged in `pkgs/pine-of-glass`. Four extensions: contextimate lists what fills
  the context window at startup and `/reload` (`Ctrl+O` cycles detail); traceline
  collapses each tool call to one line (`Ctrl+T` toggles, with thinking blocks);
  cachemire warns when the prompt cache needs attention (`/cache` for the ledger);
  meantime breaks down latency (a tempo line while it runs, slow-call notices,
  `/pace` for the ledger). Meantime is off upstream unless
  `~/.pi/agent/pi-meantime.json` sets `"enabled": true`, which ours does.
- **Experiment loops:** [pi-autoresearch](https://github.com/davebcn87/pi-autoresearch),
  packaged in `pkgs/pi-autoresearch`. `/autoresearch <goal>` sets up a benchmark
  in `.auto/` and a branch in the project's repo, then loops: try an idea, measure
  it, commit what improves the metric, revert what doesn't. It runs until
  `/autoresearch off`; `/autoresearch finalize` turns the kept experiments into
  reviewable branches, and `/autoresearch help` lists the rest. Its tools are only
  active in autoresearch mode, so outside it they cost nothing per request. Hook
  examples the agent copies from its skill come out of the store read-only, and
  need a `chmod u+w` before editing.
- **`/exit`:** a synonym for `/quit`, from a tiny local extension (`exit.ts`).
  It waits for a running agent turn to finish before exiting; `/quit` doesn't.
- **Copying code blocks:** a local extension (`copy-code.ts`). `Alt+X` or
  `/copy-code` copies the latest fenced code block in the session, and
  `/copy-code 2` the one before it. It reads the message's markdown, not the
  screen, so the copy has no margin or indent, and long lines that pi wraps
  stay whole. `Ctrl+X` and `/copy` still copy the whole last message.
- **Terminal cursor:** `showHardwareCursor` makes pi draw only the terminal's
  own cursor, not its reverse-video one, so the cursor reflects focus: hollow
  while the Alacritty window is unfocused, absent in inactive tmux panes. Before
  pi 1.2.0 the setting drew both, so a local extension stripped pi's. That
  extension made the cursor flicker on 1.2.0 and was dropped.
- **Modified Enter:** `Shift+Enter` inserts a newline and `Ctrl+Shift+Enter`
  (or `Alt+Enter`) queues a follow-up (`keybindings.json`). Alacritty sends both
  as CSI-u sequences, and tmux passes them on with `extended-keys` (both set in
  `home.nix`). An older setup mapped `Shift+Enter` to a raw LF (Ctrl+J). pi's
  `docs/terminal-setup.md` advises against that because it hides the real key,
  and it left tmux's `extended-keys` off, which pi warns about at startup.

These packages are loaded from the store, so `pi update --extensions` doesn't
touch them: bump their versions in `pkgs/`, following `UPDATING.md`.

## Testing an extension without switching

Load it into a throwaway session (`-ne` skips the configured extensions, so add
the bridge back for Claude models), running inside tmux so the footer can be
read with `tmux capture-pane -p`:

```bash
pi -ne -e <bridge>/src/index.ts -e <extension path> --no-session --no-tools \
  --model claude-bridge/claude-haiku-4-5
```

The bridge's store path is the first entry of `packages` in
`~/.pi/agent/settings.json`. An extension can also run from a clone, or from a
store path built as described in `CLAUDE.md`.

## Web access: ketch

pi has no built-in web search or fetch. And although the provider is Claude Code,
the bridge runs it with `tools: []`, so Claude Code's own WebSearch/WebFetch are
unavailable too.

ketch is a stateless Go CLI (`search`, `scrape`, `crawl`, plus `code` for public
source via grep.app and `docs` for library docs via Context7). pi reaches it
through its bash tool, guided by ketch's upstream skill (`skills/ketch` in its
source, installed in `share/skills/ketch/ketch` and listed in `settings.json`
`skills`).

Why ketch:

- **Token cost.** A skill keeps only its name and description in the system
  prompt and loads its instructions on demand. Extension tools send their full
  schemas with every request. The skill also has the agent bound every fetch
  (`--max-chars`, `--trim`).
- **Money.** The default `auto` search backend falls through keyless providers
  (Parallel, Exa, Keenable, You.com, Firecrawl, DuckDuckGo), so it costs nothing
  with no keys. Keys only raise limits, e.g. Brave's $5/month free credit:
  `KETCH_BRAVE_API_KEY`.
- **Packaging.** One Go binary with env-var config; not tied to pi.

`pkgs/ketch` wraps it to render JS-only pages with nixpkgs' Chromium
(`KETCH_BROWSER`) and to silence its self-update notices. Plain pages never
start the browser.

## Alternatives, if ketch stops fitting

- [**pi-web-access**](https://github.com/nicobailon/pi-web-access): a pi
  extension (`web_search`, `fetch_content`, `get_search_content`, `source_check`)
  supporting ~35 search providers. Worth it if we want TinyFish (free search
  and fetch; ketch has no TinyFish or Kagi backend), YouTube/video analysis, or
  its store-then-page retrieval of long pages. Costs: large (~1.1 MB of
  TypeScript), and its tool schemas ride along on every request.
- [**pi-lean-dimension**](https://github.com/coreyryanhanson/pi-lean-dimension):
  interactive Playwright browsing (click, type, and navigate by accessibility-tree
  refs rather than screenshots), declarative REST API recipes, and search via
  SearXNG only. Relevant if pi needs to drive logged-in or JS-heavy sites. As of
  2026-09 it is early (one author, AGPL-3.0), its tool toggles invalidate the
  prompt cache mid-session, and its downloaded Playwright browsers need
  replacing with nixpkgs' `playwright-driver.browsers` on NixOS.
- **Claude Code's WebSearch/WebFetch**: covered by the subscription, and
  WebFetch summarizes pages with Haiku before the main model sees them. Would
  need a bridge patch to allow those builtins in provider mode, and only works
  while claude-bridge is the provider.

## Google Calendar

`google.nix` gives pi read access to
william@weiskopf.me's calendars through [gog](https://gogcli.sh), with gog's
`gog` and `gog-calendar` skills, installed side by side in `share/skills/gog`
(gog-calendar refers to `../gog`). We chose gog
over Google's `gws` for its safety controls.

The `gog` on `PATH` is built by `pkgs/gog-safe` with a safety profile compiled in
(`gog-calendar-readonly.yaml`). It runs calendar reads and nothing else, and
always wraps event text as untrusted, since anyone can send an invite. Flags,
env vars and config can't loosen it. Its token, under the OAuth client name
`calendar-readonly`, only has the `calendar.readonly` scope.

The scope is the real limit. pi's bash runs as us, so it could reach the token
or run another gog. The profile guards against mistakes and casual prompt
injection, not a determined attacker. Give a future profile (mail, writes) its
own client name so it gets its own token.

### Logging in

Once, in the Google Cloud console:

1. Create a project and enable the Google Calendar API.
2. Set the OAuth consent screen's audience to **Internal**. For a Workspace
   account this skips Google's verification and the 7-day token expiry of
   External apps in testing.
3. Create an OAuth client of type **Desktop app** and download its JSON.

Then on each host, with the unrestricted gog (our `gog` blocks auth changes):

```bash
nix run nixpkgs#gogcli -- --client calendar-readonly auth credentials set ~/Downloads/client_secret_*.json
nix run nixpkgs#gogcli -- --client calendar-readonly auth add william@weiskopf.me --services calendar --readonly
gog auth doctor --check
gog calendar events --today
```

`auth add` opens a browser; `--manual` prints a URL to open elsewhere instead.
The token goes in GNOME Keyring, which both hosts run. gog can't read it while the
keyring is locked or unreachable, e.g. over SSH with no desktop session.

## Todoist

Doist's [Todoist CLI](https://github.com/Doist/todoist-cli), `td`, installed in every
home (`default.nix`), with its agent skill in `share/skills/todoist-cli/todoist-cli`.
nixpkgs' package doesn't install the skill, so `pkgs/todoist-cli` adds it: `td skill
install` writes it at build time, matched to `td`'s version, with no network or login.

### Logging in

Once on each host:

```bash
td auth login              # or --read-only, for a token td won't write with
td auth status
td today
```

`auth login` opens a browser for Todoist's OAuth consent; `--no-browser-open`
prints the URL instead. The token goes in GNOME Keyring under service
`todoist-cli`, and `td` shows up under Todoist's connected apps, where it can be
revoked per device.

`td` needs the keyring unlocked. In a desktop session GNOME prompts to unlock it
when asked; over SSH with no session, `td` can't log in. If that ever matters, a
personal API token from sops in `TODOIST_API_TOKEN` takes precedence over the
keyring login.

### Where td looks for a token

In order: `TODOIST_API_TOKEN`, then the keyring, then a plaintext `api_token` in
`~/.config/todoist-cli/config.json` (written only by
`--credential-store=plaintext`).

Scripts that call the API directly can get the stored token with
`TOKEN=$(td auth token view)`. Capture it; never print it, since agent
transcripts keep command output. It refuses while `TODOIST_API_TOKEN` is set.

The keyring is unlocked for the whole session and has no per-app access control,
so any process running as the user, agents included, can read the token.

## Remote access

Two browser UIs for pi sessions, on trial against each other. `remote.nix` sets
them up as user services on the NixOS hosts (imported per host in `flake.nix`).
Neither starts on its own:

| UI | Start | Open |
|---|---|---|
| [agegr/pi-web](https://github.com/agegr/pi-web) | `systemctl --user start pi-web` | `http://<host>.forge.local:30141` |
| [Pi Remote Control](https://github.com/mipsel64/pi-remote-control) (prc) | `systemctl --user start pi-remote-control` | `http://<host>.forge.local:8787` |

They work differently, which decides how they fit alongside the TUI:

- **agegr** runs sessions itself, reading and writing the same session files as
  the TUI. It can start sessions and resume any TUI session, and shows edits as
  diffs. It doesn't see what a running TUI does to an open session, nor the TUI
  what it does: if both continue the same session, it forks. Hand off instead:
  quit the TUI before continuing from the browser, and on returning `/resume`
  the session in the TUI (`/tree` to pick the branch that went on in the
  browser). Picking a model for a new session sets pi's default, as `/model`
  does; a switch puts ours back. It unloads sessions idle for 10 minutes.
- **prc** mirrors running TUI sessions, live, in both directions: prompts from
  the browser land in the TUI. Attach a session with `/rc` in the TUI (again
  after `/new`). It can't start sessions, and a session goes read-only in the
  browser once its TUI exits. Its password is generated on first start:
  `jq -r .adminPassword ~/.config/prc/config.json`. Logins last a week, but the
  server keeps them in memory, so log in again after restarting it.

Both listen on every address and rely on the firewall, which trusts only
loopback, `tailscale0`, and the Steam Deck's hotspot (`ap0`). agegr has no
password; both reject requests from other sites. agegr serves `<host>`,
`<host>.forge.local`, and IP addresses; prc only `http://<host>.forge.local:8787`.
It's plain HTTP: Headscale can't issue certificates for `tailscale serve`, so
neither can send push notifications or install as an app. Support is on Headscale's
main branch but in no release
([juanfont/headscale#2527](https://github.com/juanfont/headscale/issues/2527)), and
it solves ACME DNS-01 through a public DNS zone, which `forge.local` isn't.

agegr's sessions get the service's environment, not a shell's: `PATH` is set to
the user profile and system paths in `remote.nix`, but nothing else is. A new
session starts in a folder for the day, `~/pi-cwd/YYYYMMDD`, unless one is picked.

Local changes, none sent upstream yet:

- `pkgs/pi-claude-bridge/multi-session-registration.patch`: without it, agegr's
  sessions start with no claude-bridge models. The bridge registered its
  provider only once per process and expected later sessions to share that
  registry; agegr gives each session its own and picks its model before the
  bridge's deferred registration ran.
- `pkgs/pi-remote-control/edit-diff-view.patch`: prc showed edits as raw JSON.
- `pkgs/agegr-pi-web` packages the npm release (prebuilt), since building from
  source fetches a Google font.
- `pkgs/agegr-pi-web/pi-web.sh` runs agegr from a per-launch directory in
  `$XDG_RUNTIME_DIR`. Every copy of the release has the same Next.js preview
  secret, and a request carrying it skips agegr's Host and Origin checks, which
  are what stop DNS rebinding here. agegr replaces the secret at startup, which
  it can't do in the store.

Ending the trial: drop the loser's service and package from `remote.nix` (and,
for prc, the activation that loads its extension), or delete `remote.nix` and its
imports in `flake.nix`.

## pier

[pier](https://github.com/DArtagan/pier) (`~/repositories/pier`) runs pi on Pi Durable:
one daemon per host owns every conversation, and `pier` in any pane attaches to it as a
client. Claude comes through Earendil's pi-claude-code, on Claude Code's own login.
`pier.nix` packages it from a release tag (`pkgs/pier`) and runs `pier daemon` as a
user service on the NixOS hosts (imported per host in `flake.nix`), started at login.
Classic `pi`, above, is untouched; the two share only `~/.pi/agent`, and not for
skills.

**Skills.** `pier.nix` lists the skill directories pier offers and passes them to the
daemon as `PIER_SKILLS`; each project's `.agents/skills` and `.pi/skills` come on top.
The list is the tools' skills (`tools.nix`), the same ones pi's settings carry but not
read from them, so dropping pi leaves pier's configuration whole. It's a plain list,
not a module option: an option belongs in a Nix module of pier's own, if it gets one. A
changed list reaches the daemon at its next restart.

```bash
pier                  # in a project: continue its newest conversation, or start one
pier new              # start a new one
pier resume <n>       # attach to conversation #<n>
pier list [--all]     # conversations here (or everywhere)
systemctl --user restart pier   # pick up a new version, when idle
journalctl --user -u pier       # the daemon's log
```

In the client, `/help` lists the keys and commands. Leaving a pane (Ctrl+C on an
empty editor, `/detach`) doesn't stop its run. The storage is
`~/.local/state/pier/pier.sqlite`, the socket `$XDG_RUNTIME_DIR/pier/pier.sock`.

How the service is set up, and why:

- **A switch doesn't restart it.** A restart interrupts every pane's run. So the unit
  has `X-SwitchMethod=keep-old`, which sd-switch reads as "keep the running unit
  active" (`src/lib.rs` in sd-switch 0.6.4, read 2026-11-16; not yet watched in a
  switch). Restart it by hand when nothing is running.
- **Tools get the pane's environment.** Each conversation's tools run with the whole
  environment of the pane that last attached (devenv's PATH, `SSH_AUTH_SOCK`, …), laid
  over the unit's. The unit's `PATH` is for the daemon and Claude Code;
  `GIT_CONFIG_GLOBAL` points at the agents' git config, as the `pi` wrapper's does,
  and reaches tools since panes don't set it. A tool keeps the pane's `SSH_AUTH_SOCK`
  after the pane detaches, while that agent lives; see `todos/ssh-agent.md`.
- **`KillMode=control-group`**, systemd's default, spelled out. Durable runs each tool,
  and pi-claude-code each Claude Code, in a process group of its own, so only the
  cgroup kill reaps them: killing the daemon's process group once left a command
  running, which wrote its file after the model was told it was interrupted (pier's
  gate, 2026-11-12).
- **What a stop does to a running tool** (2026-11-16, the unit run with `systemd-run`):
  systemd sends SIGTERM to the whole cgroup at once, so a running bash call dies with
  exit code 143 while the daemon is still up, and is stored as a failed command, not
  as interrupted. Nothing it started survives. On restart, Durable picks the turn up
  without being asked, and the model sees the 143.
- **`Restart=on-failure`**: Durable resumes every conversation's work when it's back.
- **No `.socket` unit**: the daemon can't take an inherited socket.
- **Usage credits**: `PI_CLAUDE_CODE_ALLOW_USAGE_CREDITS` isn't set, so a turn that
  Claude Code would bill to Extra Usage fails instead.

Checked on thenixbeast on 2026-11-16, with the unit's command and environment under
`systemd-run`, before the first switch: a Claude turn ran bash in the pane's
directory and saw both the pane's variables and the unit's `GIT_CONFIG_GLOBAL`; the
daemon idled at about 210 MiB (355 MiB peak). The package's closure is 364 MiB at
0.7.0, pier's own pi packages and Node 26 included. 0.7.0 checked on 2026-11-24 the
same way: under `systemd-run` with the unit's environment, a Claude turn ran bash in
the pane's directory with the pane's variables and the agents' git config.

Bumping pier: `modules/pi/UPDATING.md`. Its pi packages come from its own lockfile, so
bumping pi there is pier's business (its gate, its changelog), not this repo's.
