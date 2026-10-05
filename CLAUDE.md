# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS flake-based multi-machine dotfiles. Manages three hosts: **thenixbeast** (main desktop, NixOS), **steamdeck** (Steam Deck, Jovian-NixOS), and **ginkgo-macbook** (macOS, minimal). Uses home-manager for user-level config.

## Common Commands

**Apply system changes (commit after):**
```bash
nh os switch .
```

**Preferred "update" flow:**
```bash
nh os switch . --update
devenv update
```
Once those complete, then commit using the message "Update."

**Larger changes go on a branch in a worktree under `.worktrees/`** (gitignored), then merge to `main` through a GitHub PR:
```bash
git worktree add -b <branch> .worktrees/<branch> main
```

**Enter dev shell (activates git hooks):**
```bash
direnv allow   # once, then automatic on cd
# or: devenv shell
```

**Linting (run automatically as git pre-commit hooks via devenv, using prek):**
- `nixfmt` — Nix formatting
- `deadnix` — remove dead Nix code
- `statix` — Nix linting/anti-patterns
- `shellcheck` — shell script linting
- `flake-checker` — flake.lock health (outdated or non-standard nixpkgs inputs)
- `end-of-file-fixer`, `trim-trailing-whitespace` — whitespace cleanup (skips `.patch`/`.diff`)

**Build one local package without a full switch** (new files must be `git add`ed first, or the flake can't see them):
```bash
nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.steamdeck.pkgs.callPackage ./pkgs/<name>/package.nix { }'
```

**Generate bootable ISO:**
```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage
# Result in result/iso/
```

## Architecture

### Entry Points
- **`flake.nix`** — defines all inputs and three NixOS + one home-manager configuration outputs
- **`configuration.nix`** — shared base NixOS config included by all NixOS hosts (locale, fonts, networking, nix settings)
- **`home.nix`** — shared home-manager config (shell, terminal, dev tools, media apps) applied to all users

### Host-Specific Config (`hosts/`)
Each host directory contains its own `default.nix` (hardware, filesystems, host-specific services). Hardware is detected via `nixos-facter` (`facter.json` files).

### Modules (`modules/`)
Reusable opt-in modules imported per-host in `flake.nix`:
- `sway/` — Wayland desktop (greetd, ironbar, kickoff menu)
- `stylix/` — unified theming (NixOS + home-manager variant)
- `tailscale/` — auto-connect to headscale at `headscale.immortalkeep.com` (MagicDNS `forge.local`; requires `--accept-dns=true`). See `modules/tailscale/README.md` for bootstrap, runtime toggles, and gotchas.
- `ai-server/` — local AI stack (Ollama, Open-WebUI, Speaches via Podman)
- `attic-push/` — pushes everything the host builds to the Attic cache on mini-nas, through `queued-build-hook` (see "Binary caches" in `README.md`)
- `distributed_builders/` — `my.distributedBuilders.builders` sends builds to faster hosts; `acceptBuilds` takes them. Keep the graph acyclic: Nix fills free remote slots before building locally, and builds that loop back to their sender deadlock (NixOS/nix#2029)
- `containers/` — Podman with nvidia-container-toolkit
- `gaming/` — Steam, Lutris, Wine
- `syncthing/` — file sync with predefined devices/folders
- `vim/`, `zed/`, `qutebrowser/` — app configs
- `pi/` — pi coding agent: Claude Code provider via `pi-claude-bridge`, plan quotas via `pi-quotas`, web search/fetch via the `ketch` CLI and skill. See `modules/pi/README.md` for why ketch, and alternatives (`pi-web-access`, `pi-lean-dimension`). `modules/pi/remote.nix` adds browser access over the tailnet (agegr/pi-web and Pi Remote Control, on trial), imported per host.

### Local Packages (`pkgs/`)
Packages missing from nixpkgs, or needing a newer version or local patches, each in `pkgs/<name>/package.nix` and pulled in with `pkgs.callPackage`. When one exists in nixpkgs, model it on the nixpkgs version and leave a `TODO` to switch back once nixpkgs catches up (see `pkgs/ketch`). When one is pinned to an unmerged upstream PR or carries a patch, name the PR/issue in a comment, so it's clear when to go back to a release (see `pkgs/pi-quotas`).

### Secrets Management
SOPS + age encryption. Each host has `hosts/<name>/secrets.yaml` encrypted with that host's SSH key. Key assignments are in `.sops.yaml`. Edit secrets with `sops hosts/<name>/secrets.yaml`.

### Binary Caches
Substituters: cache.nixos.org, then Attic on mini-nas (`public`, 6-month GC; `archive`, GC disabled). `archive` pins store paths that must never disappear, e.g. sources of packages whose upstream was withdrawn (`pkgs/qbz`). The procedure for pushing to it is in `README.md` under "Binary caches".

### Theming
Stylix provides unified color scheme (Solarized Light) and fonts across all apps. Override per-app stylix settings in `modules/stylix/`.

## Key Patterns

- **Module imports**: add a module path to the host's module list in `flake.nix`, not in `configuration.nix`
- **Home-manager**: configured inline in `flake.nix` per host, importing `./home.nix` plus host-specific extras
- **`ai-server` caveat**: if `nixos-rebuild switch` fails due to GPU container options, temporarily comment out `./modules/ai-server` in `flake.nix`, reboot, then re-enable
- **nixpkgs channel**: `nixos-unstable` for all hosts
- **Configs that apps also write to** (Claude Code, pi and its extensions): merge the keys we manage with `lib/merge-json-into.nix` in a home-manager activation, rather than `home.file`, which symlinks a read-only file. See `modules/pi` and `claudeSettings` in `home.nix`.

## Git Gotchas

- **`git diff` uses difftastic.** Pass `--no-ext-diff` whenever the output must be a real patch (`git diff`/`git show` piped to `git apply`).
- **Hooks are shared across worktrees, but their config path isn't.** `.git/hooks/pre-commit` hardcodes the `.pre-commit-config.yaml` of whichever checkout last entered devenv, so commits from another checkout can run prek against the wrong tree. A staged file has silently gone missing from a commit this way. After committing, check `git show --stat HEAD`. After removing a worktree, re-enter devenv in the main checkout so the hook points back at it.
- **prek stashes unstaged changes while hooks run.** If a commit is interrupted, they may not come back; prek keeps a copy in `.devenv/state/prek/patches/<timestamp>.patch` (`git apply` it).
