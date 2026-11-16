{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_24,
}:

# pier: pi on Pi Durable, one daemon per host with thin clients (~/repositories/pier,
# DArtagan/pier). Its pi packages come from its own lockfile, not from nixpkgs' pi, and
# pi-claude-code is a codeload tarball in it, which fetchNpmDeps takes like any other.
# `npm run build` (run by default) compiles its TypeScript to dist/: Node won't strip
# types under node_modules, where this installs it.
buildNpmPackage (finalAttrs: {
  pname = "pier";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "DArtagan";
    repo = "pier";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jo1PcTu8s3fuGpFLVhgkVsSFWpJElbGnDc3d6NxBb6k=";
  };

  npmDepsHash = "sha256-eNvl/RUh8WVL7TCdPV66OLfa9uQYNRSVWpoiPqVZ2W0=";

  # It runs on Node 24 (`engines`), and its runtime is whichever node builds it.
  nodejs = nodejs_24;

  meta = {
    description = "pi on Pi Durable: one daemon per host, thin clients";
    homepage = "https://github.com/DArtagan/pier";
    changelog = "https://github.com/DArtagan/pier/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "pier";
  };
})
