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

**Enter dev shell (activates git hooks):**
```bash
direnv allow   # once, then automatic on cd
# or: devenv shell
```

**Linting (run automatically as git pre-commit hooks via devenv):**
- `nixfmt` — Nix formatting
- `deadnix` — remove dead Nix code
- `statix` — Nix linting/anti-patterns
- `shellcheck` — shell script linting

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
- `sway/` — Wayland desktop (greetd, i3status-rust, kickoff menu)
- `stylix/` — unified theming (NixOS + home-manager variant)
- `tailscale/` — auto-connect to headscale at `headscale.immortalkeep.com`
- `ai-server/` — local AI stack (Ollama, Open-WebUI, Speaches via Podman)
- `containers/` — Podman with nvidia-container-toolkit
- `gaming/` — Steam, Lutris, Wine
- `syncthing/` — file sync with predefined devices/folders
- `vim/`, `zed/`, `qutebrowser/` — app configs

### Secrets Management
SOPS + age encryption. Each host has `hosts/<name>/secrets.yaml` encrypted with that host's SSH key. Key assignments are in `.sops.yaml`. Edit secrets with `sops hosts/<name>/secrets.yaml`.

### Theming
Stylix provides unified color scheme (Solarized Light) and fonts across all apps. Override per-app stylix settings in `modules/stylix/`.

## Key Patterns

- **Module imports**: add a module path to the host's module list in `flake.nix`, not in `configuration.nix`
- **Home-manager**: configured inline in `flake.nix` per host, importing `./home.nix` plus host-specific extras
- **`ai-server` caveat**: if `nixos-rebuild switch` fails due to GPU container options, temporarily comment out `./modules/ai-server` in `flake.nix`, reboot, then re-enable
- **nixpkgs channel**: `nixos-unstable` for all hosts
