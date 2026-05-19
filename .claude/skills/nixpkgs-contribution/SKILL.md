---
description: "Contribute to NixOS/nixpkgs — version bumps and package fixes. Use when the user wants to update a package version, fix a package build, add missing runtime dependencies, or submit any PR to the nixpkgs repository."
---

# Nixpkgs Contribution Protocol

## Repository setup

- Fork: `~/repositories/nixpkgs`
- `origin`: `git@github.com:DArtagan/nixpkgs.git` (user's fork)
- `upstream`: `https://github.com/NixOS/nixpkgs.git`

## Workflow

### 1. Create a fresh branch

```bash
cd ~/repositories/nixpkgs
git fetch upstream master --quiet
git checkout -b <branch-name> upstream/master
```

Always start from a clean `upstream/master`. One branch per PR.

### 2. Check for existing PRs

Before starting work, check if someone has already submitted the same change:

```bash
gh pr list --repo NixOS/nixpkgs --search "<pkg>" --state open
gh pr list --repo NixOS/nixpkgs --search "<pkg>" --state merged --limit 10
```

For version bumps, also check if the current nixpkgs master already has the version (it may be merged but not yet in a channel release):

```bash
git log upstream/master --oneline --all -- 'pkgs/by-name/<prefix>/<pkg>/' | head -10
```

Many packages have `passthru.updateScript` that bots or maintainers run automatically. If the update is already merged or in-flight, skip it.

### 3. Make changes (if no existing PR found)

**Version bump:**
```bash
nix-shell -p nix-update --run 'nix-update <pkg> --version <version>'
```
This updates version, source hash, cargo hash, npm deps hash, etc. automatically.

**Package fix** (missing deps, patches, wrapper changes):
Edit `pkgs/by-name/<prefix>/<pkg>/package.nix` directly.

### 4. Format

```bash
nix fmt -- pkgs/by-name/<prefix>/<pkg>/package.nix
```

nixpkgs CI runs treefmt and will reject unformatted code. Always format before committing.

### 5. Build and test locally

```bash
nix-build -A <pkg>
./result/bin/<pkg>
```

Launch the binary and verify the fix or new version works. Ask the user to confirm functionality.

### 6. Commit

**Commit message format:**
- Version bump: `<pkg>: <old-version> -> <new-version>`
- Package fix: `<pkg>: <short description of fix>`

Include a body with details (changelog link for bumps, explanation for fixes).

**AI/automation disclosure (per [nixpkgs policy](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy)):**

- **Minor changes** (version bumps via `nix-update`, simple dependency fixes): exempt from disclosure — omit any AI trailer.
- **Complex PRs, new packages, tree-wide work**: add an `Assisted-by:` Git commit trailer:
  ```
  Assisted-by: Claude Code (claude-opus-4-6)
  ```
- **NEVER use `Co-authored-by:` for AI tools.** A commit with `Co-authored-by: Claude` but no `Assisted-by:` is a policy violation and can be automatically closed.
- PR descriptions and review comments must disclose LLM use separately from commits when applicable.

```bash
git add pkgs/by-name/<prefix>/<pkg>/package.nix
git commit -m "<message>"
```

### 7. Push and create PR

```bash
git push origin <branch-name>
```

Fetch the latest PR template from upstream and use it as the body:

```bash
TEMPLATE=$(curl -fsSL https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/master/.github/PULL_REQUEST_TEMPLATE.md)
```

Prepend a description of the change (changelog link for version bumps, explanation for fixes) above the template content. Check off applicable boxes based on what was actually done. Then create the PR:

```bash
gh pr create --repo NixOS/nixpkgs --base master --head DArtagan:<branch-name> \
  --title "<commit title>" --body "$(cat <<EOF
<description of the change>

$TEMPLATE
EOF
)"
```

Aim to fulfill as many checkboxes as possible/applicable.

### 8. Run nixpkgs-review

**After** the PR is created (not before):

```bash
nix shell nixpkgs#nixpkgs-review --command nixpkgs-review pr <PR-number> --no-shell
```

Use the `pr` subcommand, not `rev`. The `rev` subcommand creates shallow worktrees that fail to merge local branches (unrelated histories error).

Once it passes, update the PR body to check the nixpkgs-review box.

## Pitfalls

- **Never amend commits after `nixpkgs-review` runs.** It creates git worktrees that can corrupt branch state on amend, producing orphaned commits with 50k+ changed files. If you need to change something after nixpkgs-review, create a new commit.
- **Keep PRs focused.** One logical change per PR — don't combine a version bump with a package fix.
- **Check `nix fmt` output says "0 changed"** before committing. If it reformats your code, the diff is what CI expects.
