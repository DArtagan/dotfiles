# Outstanding work

Transient work specs. Each is self-contained: enough verified context to start a
session cold, plus a prompt to open with.

These are **not** documentation of the running config; that lives in
[`CLAUDE.md`](../CLAUDE.md), [`README.md`](../README.md) and the modules' own
READMEs. When a piece of work lands, whatever it leaves behind that is
permanently true gets written there, and the spec here is deleted. A file
sitting in this directory means the work has not been done.

## Open

**[pi-durable.md](pi-durable.md) — pi on Pi Durable: packaging and the module**
A Pi Durable harness in a per-host user service owns every pi session; tmux panes
(later web and phone) attach as clients. Built in its own repo, pier
(`~/repositories/pier`, local only), whose `todos/poc.md` is the project spec. Its
first step passed on 2026-10-29: pi-claude-bridge runs on Durable through a shim,
including crash, compaction and fork. This spec is the Nix side: `pkgs/pier` and a
user-service module. Not started; waits on pier's daemon and client.

**[ssh-agent.md](ssh-agent.md) — one SSH agent, unlocked per terminal session**
Every `eval (ssh-agent -c)` starts another agent and none of them get stopped
(22 were running on thenixbeast on 2026-10-21). The plan is 1Password's agent,
which makes each new terminal session ask for approval, forwarded from the
steamdeck, with a passphrase-per-session fallback for the phone. Not started:
Will wants it written down, not built yet.

## Writing a spec

What makes these useful when opened cold, months later:

- **State what was verified and when.** "Verified 2026-10-21" beats an assertion
  with no provenance. Anything not checked should say so.
- **Record why, not just what.** A future session that knows why an approach was
  rejected will not re-propose it.
- **Include the prompt.** Ending with the literal text to open a session with
  removes the work of reconstructing intent.
- **Note decisions already made, and by whom.** Where the user has expressed a
  preference, record it verbatim so it is not relitigated.
- **Be honest about wrong turns.** Inheriting bad reasoning is worse than
  inheriting no reasoning.
