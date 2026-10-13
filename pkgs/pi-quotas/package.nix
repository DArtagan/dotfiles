{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

# Plan quotas (5h/7d) in pi's footer, plus /quotas and quota warnings. pi loads it
# from the store path (settings.json `packages`); it ships TypeScript with no runtime
# dependencies, and pi supplies the @mariozechner/* modules it imports.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-quotas";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "latentminds-ai";
    repo = "pi-quotas";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5Yc93eFWpSBx1V1Q0xT1sEcz07sAyfLsEVaJQInsxu8=";
  };

  patches = [
    # Adds a `claude-bridge` quota provider, read from the anthropic-ratelimit-unified-*
    # headers that pi-claude-bridge passes to after_provider_response (its
    # rate-limit-headers.patch, elidickinson/pi-claude-bridge#171). Local; not yet sent
    # upstream.
    ./rate-limit-headers.patch
  ];

  # The extensions import ../package.json at runtime for their version string.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json src README.md LICENSE $out/
    runHook postInstall
  '';

  meta = {
    description = "Quota monitoring for the pi coding agent";
    homepage = "https://github.com/latentminds-ai/pi-quotas";
    license = lib.licenses.mit;
  };
})
