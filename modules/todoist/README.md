# todoist

Doist's [Todoist CLI](https://github.com/Doist/todoist-cli), `td`, logged in
declaratively from a sops-managed personal API token, with its agent skill
linked into `~/.pi/agent/skills`.

- `default.nix` (NixOS) decrypts `todoist/api_token` from `./secrets.yaml` to
  `/run/secrets/todoist/api_token`, readable only by `my.todoist.user`.
- `hm.nix` (home-manager) puts a wrapped `td` on `PATH` that reads the token on
  each run, links `td`'s own skill for pi, and links `~/.config/todoist/token`
  to the secret for scripts that call the API directly.

## Why a personal token, not `td auth login`

`td auth login` keeps an OAuth token in GNOME Keyring and needs a browser on
every host. `TODOIST_API_TOKEN` takes precedence over that login, so a token
from sops makes the setup declarative and gives `td` and the scripts the same
credential.

What it costs:

- **No read-only mode.** A personal token always has full access. `td auth
  login --read-only` is the only way to get a token the CLI won't write with.
- **One credential.** Revoking it means generating a new one in Todoist and
  updating `secrets.yaml`, after which both hosts need a switch.

Neither option hides the token from processes running as the user. The keyring
is unlocked for the whole session and has no per-app access control, and the
decrypted secret is readable by its owner. That includes agents.

## Setting or rotating the token

Get the token from Todoist: Settings → Integrations → Developer → API token.
Then, from a terminal (sops prompts for the SSH key's passphrase):

```bash
sops modules/todoist/secrets.yaml
```

Replace the value of `todoist.api_token`, save, and switch each host. Check:

```bash
td auth status
td today
```

`secrets.yaml` is encrypted for both hosts and both users' keys through the
shared rule in `.sops.yaml`.
