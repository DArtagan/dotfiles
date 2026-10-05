# Updating pi and its packages

pi itself comes from nixpkgs. Everything else pi loads is packaged in `pkgs/` and
loaded from the store, so neither `pi update --extensions` nor `nh os switch .
--update` moves it: each one is bumped by hand, as below. Don't `pi install` or
`pi update` these either. `piSettings` replaces `packages` in `settings.json` on
every switch, so anything pi installs itself drops out of the list, though its files
stay behind in `~/.pi/agent/npm` or `~/.pi/agent/git`.

## What's where

| Package | Source | Pinned by | Other hashes | Carries |
|---|---|---|---|---|
| pi (`pi-coding-agent`) | nixpkgs | `flake.lock` | | |
| `pi-claude-bridge` | GitHub commit (no tags upstream) | `rev`, `hash` | `npmDepsHash` | two patches |
| `pi-quotas` | GitHub commit on a fork | `rev`, `hash` | | the fork itself ([#51](https://github.com/latentminds-ai/pi-quotas/pull/51)) |
| `pine-of-glass` | GitHub tag | `version`, `hash` | | |
| `rpiv-ask-user-question` | npm tarball | `version`, `hash` | `rpiv-config` tarball | |
| `pi-remote-control` | GitHub tag | `version`, `hash` | `cargoHash`, `npmDeps` hash, `ws` tarball | one patch |
| `agegr-pi-web` | npm tarball, plus the repo's lockfile | `version`, `hash` | lockfile hash, `npmDepsHash` | one patch |
| `ketch` | GitHub tag | `version`, `hash` | `vendorHash` | a TODO to return to nixpkgs |

pi moves with the regular update flow in `CLAUDE.md`. After it does, check the
extensions as in step 7 below: the bridge, pi-remote-control and agegr pi-web all
lean on pi internals, and `terminal-cursor.ts` wraps a private pi-tui method (it
warns at startup if that method is gone).

## Bumping a package

### 1. Find the new version

```bash
gh release list -R tmustier/pine-of-glass -L 3          # GitHub releases
git ls-remote --tags --refs https://github.com/mipsel64/pi-remote-control | tail -3
npm view @juicesharp/rpiv-ask-user-question version     # npm releases
```

- **pi-claude-bridge** has no tags. Use the "Release x.y.z" commit, and check that
  its version matches `npm view pi-claude-bridge version`:
  ```bash
  gh api 'repos/elidickinson/pi-claude-bridge/commits?per_page=100' \
    --jq '.[] | select(.commit.message | test("^Release ")) | "\(.sha) \(.commit.message | split("\n")[0])"'
  ```
- **pi-quotas** is pinned to a fork for an unmerged PR. Check it first:
  `gh pr view 51 -R latentminds-ai/pi-quotas --json state,mergedAt`. Once it's merged
  and released, point `src` back at `latentminds-ai/pi-quotas` at the release tag,
  and drop the fork comment and the README's "Pinned to #51" note. Until then, a bump
  means a newer commit on the PR branch.
- **ketch**: if nixpkgs has caught up (`nix eval --raw .#nixosConfigurations.thenixbeast.pkgs.ketch.version`),
  follow the TODO in its `package.nix` rather than bumping.

### 2. Read what changed

Read the changelog or the commits since our version, looking for:

- **A higher minimum pi version.** Look at `peerDependencies` (pine-of-glass
  declares `>=0.86.0`) and the changelog, and compare with pi's version:
  `nix eval --raw .#nixosConfigurations.thenixbeast.pkgs.pi-coding-agent.version`.
- **New runtime dependencies.** pi supplies `@earendil-works/pi-ai`,
  `pi-agent-core`, `pi-coding-agent`, `pi-tui` and `typebox`. Anything else an
  extension imports has to be in its store path. For the plain-copy packages
  (pine-of-glass, pi-quotas, rpiv-ask-user-question), list the bare imports in a
  checkout of the new version:
  ```bash
  grep -rhoE "from ['\"][^.'\"][^'\"]*['\"]|import\(['\"][^.'\"][^'\"]*['\"]\)" --include=*.ts . | sort | uniq -c
  ```
  `node:` builtins are fine. For anything else, follow rpiv-ask-user-question, which
  unpacks `rpiv-config` into `$out/node_modules`. Its `version` covers both tarballs
  because the two are released together. If `npm view
  @juicesharp/rpiv-ask-user-question@<new> dependencies` stops matching, give
  `rpiv-config` its own version. Never put pi's own packages in `node_modules`: a
  second copy duplicates its classes and registries, and pi warns about it.
- **Files the install phase copies.** The plain-copy packages copy named paths.
  Check them against the new `package.json` `pi` manifest and `files` list.
- **Config or keybinding changes** that the README describes.
- **Whether our local patches were merged upstream**, in which case drop them.

### 3. Update the version and hashes

Set the new `version` (or `rev`). Then, for each hash that changes, set it to `""`,
build (step 6), and copy the `got:` value from the error. Do one hash at a time,
starting with `src`: later hashes (`npmDepsHash`, `cargoHash`, `vendorHash`, the
`npmDeps` hash) depend on it.

npm tarballs don't need the build round trip. Their `hash` is the registry's own
integrity value:

```bash
npm view @juicesharp/rpiv-config@2.13.0 dist.integrity
```

For pi-remote-control, the `ws` version comes from upstream's root
`package-lock.json` at the new tag. For agegr pi-web, the lockfile is fetched from
the repo at the same tag; its root dependencies should match the npm release's
`package.json`.

### 4. Bring the patches forward

If a patch no longer applies, rebase it in a clone of the new version and regenerate it:

```bash
git clone https://github.com/<owner>/<repo> && cd <repo> && git checkout <new rev>
git apply --3way /path/to/dotfiles/pkgs/<name>/<patch>   # fix any conflicts
git diff --no-ext-diff > /path/to/dotfiles/pkgs/<name>/<patch>
```

`--no-ext-diff` matters: `git diff` here uses difftastic. Keep each patch's comment
in `package.nix` current, and note when one has been sent upstream.

The `lockfile-integrity.patch` files (bridge and agegr) add `integrity` to lockfile
entries that lack it, since `fetchNpmDeps` requires it. The missing entries change
with the lockfile, so regenerate the patch rather than rebasing it. List the entries
that need it:

```bash
jq -r '.packages | to_entries[] | select(.value.resolved and (.value.integrity | not))
  | "\(.key) \(.value.version)"' package-lock.json
```

Look each one up with `npm view <name>@<version> dist.integrity`, using the package
name from the end of the path, and add an `"integrity"` line after its `"resolved"`
line. Then `git diff --no-ext-diff package-lock.json`. If the list is empty, delete
the patch.

### 5. Keep the docs in step

Update anything in `modules/pi/README.md` (or the comments in `package.nix`) that the
new version makes wrong: keys, commands, config files, pinned PRs, caveats.
`remote.nix` finds the prc extension in `packages` by the name
`pi-remote-control-extension`, so a `pname` change needs that match updated too.

### 6. Build

New files must be `git add`ed first, or the flake can't see them:

```bash
nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.thenixbeast.pkgs.callPackage ./pkgs/<name>/package.nix { }'
```

### 7. Test

Load the new store path in a throwaway session, as in the README's "Testing an
extension without switching". Run it in tmux, read the screen with `tmux
capture-pane -p`, and check that it appears under `[Extensions]` with no load
errors. Then try what it does:

| Package | Smoke test |
|---|---|
| pi-claude-bridge | Load `<new store path>/lib/node_modules/pi-claude-bridge/src/index.ts` in place of the current bridge; a prompt gets an answer from `claude-bridge/claude-haiku-4-5`. |
| pi-quotas | The 5h/7d windows appear in the footer; `/quotas` answers. |
| pine-of-glass | The contextimate panel at startup; after one prompt, the cachemire/traceline turn line; `/cache` and `/pace` answer (`/pace` needs `pi-meantime.json` with `"enabled": true`, which works project-level in `<cwd>/.pi/`). |
| rpiv-ask-user-question | Ask the model to use `ask_user_question`; the dialog opens and the chosen answer reaches the model. |
| pi-remote-control | After a switch: `systemctl --user restart pi-remote-control`, `/rc` in a TUI session, and the session shows at `http://<host>.forge.local:8787`. |
| agegr-pi-web | After a switch: `systemctl --user restart pi-web`; `http://<host>.forge.local:30141` lists sessions, and a new one gets claude-bridge models. |
| ketch | `ketch search --json --limit 3 "<query>"` returns results. |

Kill the tmux session afterwards. Say in the commit or PR what wasn't tested.

### 8. Build the hosts and commit

```bash
nix build --no-link .#nixosConfigurations.thenixbeast.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.steamdeck.config.system.build.toplevel
nix eval --raw .#homeConfigurations.will.activationPackage.drvPath   # the Mac
```

Commit with a message like `pi: bump pine-of-glass to 0.16.0`, then check `git show
--stat HEAD` (see "Git Gotchas" in `CLAUDE.md`). Switching (`nh os switch .`) is up
to the user.

## Adding a package

Follow the closest existing package:

- **Plain TypeScript, no runtime dependencies** (pi-quotas, pine-of-glass):
  `stdenvNoCC.mkDerivation` that copies `package.json` and the files its `pi`
  manifest names. Prefer a GitHub tag.
- **A few runtime dependencies** (rpiv-ask-user-question): the same, plus each
  dependency's npm tarball unpacked into `$out/node_modules`. Use the npm tarball for
  the package itself too when the source lives in a monorepo.
- **Many dependencies, or a lockfile** (pi-claude-bridge): `buildNpmPackage` with
  `npmInstallFlags = [ "--omit=dev" ]` and `dontNpmBuild = true`. Keep pi's packages
  out (they're usually dev or peer dependencies).

Then add `"${<name>}"` to `packages` in `default.nix` (`callPackage` it in the
`let`), add a README bullet, and add it to the pi line in `CLAUDE.md`'s module list.
Name any pinned PR or carried patch in a comment, as `CLAUDE.md` asks.
