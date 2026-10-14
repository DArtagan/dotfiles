{
  buildNpmPackage,
  fetchFromGitHub,
  jq,
  lib,
}:

# Replaces `pi install npm:pi-claude-bridge` so the bridge can carry local patches.
# pi loads it from the store path (settings.json `packages`); the source ships as
# TypeScript that pi compiles at load time, so there is no build step.
buildNpmPackage {
  pname = "pi-claude-bridge";
  version = "0.9.3";

  # No v0.9.3 tag upstream; this is the "Release 0.9.3" commit, which matches npm.
  src = fetchFromGitHub {
    owner = "elidickinson";
    repo = "pi-claude-bridge";
    rev = "874fa7c2678456336f23b64e784e2057e608d83e";
    hash = "sha256-2P81N6xWuvJdB3w7egU8QNguXWkOyyRUDePveXY7p0c=";
  };

  npmDepsHash = "sha256-5M7jltFSHmRPN6NrTWENBzeLDMgmF/m0ByiWLmAiP8I=";

  patches = [
    # Register the provider in every session of a host that runs several in one process
    # (agegr/pi-web), which otherwise start with no claude-bridge models. Local; not yet
    # sent upstream.
    ./multi-session-registration.patch
  ];

  # pi supplies its own packages (the bridge's peer dependencies) to extensions at load
  # time, and dev dependencies (pi again, typescript, tsx) are only for upstream's
  # tests. Drop both before fetchNpmDeps (which also runs postPatch) reads the
  # lockfile: it fetches every entry, whatever npm will install, and some dev entries
  # lack the `integrity` it requires. Without the dev entries, npm would try to fetch
  # pi to satisfy the peers.
  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies, .peerDependencies)' package.json > package.json.new
    mv package.json.new package.json
    ${lib.getExe jq} 'del(.packages[""].devDependencies, .packages[""].peerDependencies)
      | .packages |= with_entries(select(.value.dev != true))' \
      package-lock.json > package-lock.json.new
    mv package-lock.json.new package-lock.json
  '';
  dontNpmBuild = true;

  meta = {
    description = "Pi extension that uses Claude Code (via Agent SDK) as a model provider";
    homepage = "https://github.com/elidickinson/pi-claude-bridge";
    license = lib.licenses.mit;
  };
}
