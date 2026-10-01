# pi module

Installs [pi](https://pi.dev) and merges the keys we manage into its config
(`~/.pi/agent/settings.json`, `~/.pi/agent/claude-bridge.json`). pi writes its
own runtime state into the same files, so they are merged on each switch rather
than symlinked; see `lib/merge-json-into.nix`.

- **Model provider:** [`pi-claude-bridge`](https://github.com/elidickinson/pi-claude-bridge),
  which runs Claude Code (via the Agent SDK) on the Claude subscription. Packaged in
  `pkgs/pi-claude-bridge` to carry local patches, and loaded from the store.
- **Plan quotas:** [pi-quotas](https://github.com/latentminds-ai/pi-quotas), packaged
  in `pkgs/pi-quotas`. Shows the Claude plan's 5h/7d windows in the footer, plus
  `/quotas` and near-limit warnings. Pinned to
  [#51](https://github.com/latentminds-ai/pi-quotas/pull/51), which reads Claude
  Code's login so claude-bridge models get quotas; it never refreshes that login,
  so an expired one shows until Claude Code refreshes it.
- **Web access:** [ketch](https://ketch.run), packaged in `pkgs/ketch`. See below.
- **`/exit`:** a synonym for `/quit`, from a tiny local extension (`exit.ts`).
  It waits for a running agent turn to finish before exiting; `/quit` doesn't.
- **Terminal cursor:** a local extension (`terminal-cursor.ts`) shows the
  terminal's own cursor in place of the reverse-video one pi paints, so it
  reflects focus: hollow while the Alacritty window is unfocused, absent in
  inactive tmux panes. Covers the editor and selector search boxes, but not the
  `/settings` search, which doesn't mark its cursor. It wraps a private pi-tui
  method; if a pi update removes it, the extension warns at startup, and if the
  painted cursor changes shape, it quietly falls back to pi's painted cursor.
  Upstream fixes ([#5268](https://github.com/earendil-works/pi/pull/5268),
  [#9924](https://github.com/earendil-works/pi/pull/9924)) were auto-closed
  unreviewed; if pi stops painting the cursor itself when `showHardwareCursor`
  is on (issue [#3896](https://github.com/earendil-works/pi/issues/3896)),
  set that and drop the extension.
- **Modified Enter:** `Shift+Enter` inserts a newline and `Ctrl+Shift+Enter`
  (or `Alt+Enter`) queues a follow-up (`keybindings.json`). Alacritty sends both
  as CSI-u sequences, and tmux passes them on with `extended-keys` (both set in
  `home.nix`). An older setup mapped `Shift+Enter` to a raw LF (Ctrl+J). pi's
  `docs/terminal-setup.md` advises against that because it hides the real key,
  and it left tmux's `extended-keys` off, which pi warns about at startup.

The bridge and pi-quotas are loaded from the store, so `pi update --extensions`
doesn't touch them: bump their versions in `pkgs/`.

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
through its bash tool, guided by ketch's upstream skill (`skills/ketch`, listed
in `settings.json` `skills`).

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

The package wraps `ketch` to render JS-only pages with nixpkgs' Chromium
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
