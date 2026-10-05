{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:

# Replaces `pi install npm:pi-claude-bridge` so the bridge can carry local patches.
# pi loads it from the store path (settings.json `packages`); the source ships as
# TypeScript that pi compiles at load time, so there is no build step.
buildNpmPackage {
  pname = "pi-claude-bridge";
  version = "0.9.1";

  # No v0.9.1 tag upstream; this is the "Release 0.9.1" commit, which matches npm.
  src = fetchFromGitHub {
    owner = "elidickinson";
    repo = "pi-claude-bridge";
    rev = "9dafd0301faad79cf6a1974d92af424189476b5d";
    hash = "sha256-Y3uNnHRrcdc3v9PJepG9W+GjBNmq1V9XW08aeV/UM5U=";
  };

  npmDepsHash = "sha256-ZKaXrGJmOD59qTmOwJF/aTxvtZGr4TFPOzGDozU0uNQ=";

  patches = [
    # Seven dev-only lockfile entries lack `integrity`, which fetchNpmDeps requires.
    ./lockfile-integrity.patch
    # Register the provider in every session of a host that runs several in one process
    # (agegr/pi-web), which otherwise start with no claude-bridge models. Local; not yet
    # sent upstream.
    ./multi-session-registration.patch
  ];

  # Dev dependencies (pi itself, typescript, tsx) are only for upstream's tests; pi
  # supplies its own packages to extensions at load time.
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  meta = {
    description = "Pi extension that uses Claude Code (via Agent SDK) as a model provider";
    homepage = "https://github.com/elidickinson/pi-claude-bridge";
    license = lib.licenses.mit;
  };
}
