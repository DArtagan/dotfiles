# todoist

Doist's [Todoist CLI](https://github.com/Doist/todoist-cli), `td`, with its agent
skill linked into `~/.pi/agent/skills`. Imported by `home.nix`, so every home
gets it.

## Logging in

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

## Where td looks for a token

In order: `TODOIST_API_TOKEN`, then the keyring, then a plaintext `api_token` in
`~/.config/todoist-cli/config.json` (written only by
`--credential-store=plaintext`).

Scripts that call the API directly can get the stored token with
`TOKEN=$(td auth token view)`. Capture it; never print it, since agent
transcripts keep command output. It refuses while `TODOIST_API_TOKEN` is set.

The keyring is unlocked for the whole session and has no per-app access control,
so any process running as the user, agents included, can read the token.
