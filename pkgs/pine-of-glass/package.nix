{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

# Observability extensions for pi: contextimate (what fills the context window),
# traceline (one line per tool call), cachemire (prompt-cache warnings), and meantime
# (latency; inert until its config enables it). pi loads it from the store path
# (settings.json `packages`); it ships TypeScript with no runtime dependencies, and pi
# supplies the @earendil-works/* modules it imports.
stdenvNoCC.mkDerivation rec {
  pname = "pine-of-glass";
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "tmustier";
    repo = "pine-of-glass";
    tag = "v${version}";
    hash = "sha256-jOYCPHNQnv1YyeFzatOkbsDxI663fdS99stXLx5nohU=";
  };

  # package.json's `pi.extensions` lists the extensions; they share extensions/_lib.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r package.json extensions docs README.md LICENSE $out/
    runHook postInstall
  '';

  meta = {
    description = "Observability extensions for the pi coding agent";
    homepage = "https://github.com/tmustier/pine-of-glass";
    license = lib.licenses.mit;
  };
}
