{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

# Autonomous experiment loop for pi (/autoresearch): run a benchmark, keep what
# improves the metric, revert what doesn't, repeat. pi loads it from the store path
# (settings.json `packages`); it ships TypeScript with no runtime dependencies, and pi
# supplies the @earendil-works/* and @sinclair/typebox modules it imports.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-autoresearch";
  version = "1.9.0";

  src = fetchFromGitHub {
    owner = "davebcn87";
    repo = "pi-autoresearch";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1Pc5pTjWOt00QDu/lRmhSJrpolzBAy5PiFDmGItZY8Y=";
  };

  # package.json's `pi` manifest names extensions/ and skills/; the dashboard export
  # reads its template and logo from assets/.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json extensions skills assets README.md CHANGELOG.md LICENSE $out/
    runHook postInstall
  '';

  meta = {
    description = "Autonomous experiment loop for the pi coding agent";
    homepage = "https://github.com/davebcn87/pi-autoresearch";
    license = lib.licenses.mit;
  };
})
