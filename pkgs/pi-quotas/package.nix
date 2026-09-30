{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

# Plan quotas (5h/7d) in pi's footer, plus /quotas and quota warnings. pi loads it
# from the store path (settings.json `packages`); it ships TypeScript with no runtime
# dependencies, and pi supplies the @mariozechner/* modules it imports.
stdenvNoCC.mkDerivation {
  pname = "pi-quotas";
  version = "0.5.0-unstable-2026-09-29";

  # latentminds-ai/pi-quotas#51 ("report Anthropic quotas for claude-bridge models"),
  # which reads Claude Code's login so claude-bridge models get quotas. Move back to
  # upstream once it is merged and released.
  src = fetchFromGitHub {
    owner = "wayne930242";
    repo = "pi-quotas";
    rev = "caa30da4f6d3d3e2a57edbb85e8de1f856f7ee6b";
    hash = "sha256-2A4e8hv3Oapxoc05lTAuc5JmdePf3AiiampkPm4yWao=";
  };

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
}
