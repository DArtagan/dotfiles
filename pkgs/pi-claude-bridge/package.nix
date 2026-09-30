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
  version = "0.9.0";

  # No v0.9.0 tag upstream; this is the "Release 0.9.0" commit, which matches npm.
  src = fetchFromGitHub {
    owner = "elidickinson";
    repo = "pi-claude-bridge";
    rev = "20485034a865c64088dc4ba8d0cb3c23df85aada";
    hash = "sha256-UprlmG6K97pHXqlkBDxU9qoKI/wkonXSfZJbs99s1xE=";
  };

  npmDepsHash = "sha256-pLpEarP11q+ePUE/dsJavOVJ9fnLtfo57dg8ICzYn8g=";

  patches = [
    # Five dev-only lockfile entries lack `integrity`, which fetchNpmDeps requires.
    ./lockfile-integrity.patch
    # Show plan utilization (5h/7d) in pi's footer. Not yet upstream.
    ./footer-rate-limits.patch
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
