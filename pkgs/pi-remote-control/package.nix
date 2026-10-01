{
  cacert,
  fetchFromGitHub,
  fetchNpmDeps,
  fetchurl,
  lib,
  nodejs,
  npmHooks,
  openssl,
  pkg-config,
  rustPlatform,
  stdenvNoCC,
}:

# Pi Remote Control: the `prc` server, whose web UI mirrors running pi TUI sessions,
# and (passthru.extension) the pi extension that attaches a session with `/rc`.
let
  version = "0.1.8";

  src = fetchFromGitHub {
    owner = "mipsel64";
    repo = "pi-remote-control";
    tag = "v${version}";
    hash = "sha256-77+FZ6JmnHpXlXeeuMS2st1neTW2nDqOCTvF3LoyKQA=";
  };

  # pi loads the extension from the store (settings.json `packages`). Its only runtime
  # dependency is ws, at the version upstream's lockfile pins; the rest of that
  # lockfile is dev tooling (pi itself, Playwright).
  ws = fetchurl {
    url = "https://registry.npmjs.org/ws/-/ws-8.21.3.tgz";
    hash = "sha512-201TZ/kPWxoPr/OKWjquZR1SWKXcvxdH+e1xrx89b3YbmzLMFCLfnaG1HFIgWzJOEWZ7MvpK++odZufgYR50Rw==";
  };

  extension = stdenvNoCC.mkDerivation {
    pname = "pi-remote-control-extension";
    inherit version src;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/node_modules/ws
      cp -r package.json extensions LICENSE $out/
      tar xzf ${ws} --strip-components=1 -C $out/node_modules/ws
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "pi-remote-control";
  inherit version src;

  patches = [
    # Show edit results as a diff (pi stores a unified patch in details.patch) rather
    # than the raw arguments. Local; not yet sent upstream.
    ./edit-diff-view.patch
  ];

  cargoRoot = "server";
  buildAndTestSubdir = "server";
  cargoHash = "sha256-O3gY1UWtA1DZkb3diFumdU4ym7sctJtCa/JlZQSPyCQ=";

  # The web UI is built first and embedded into the binary (include_dir!).
  npmRoot = "server/web";
  npmDeps = fetchNpmDeps {
    name = "pi-remote-control-${version}-npm-deps";
    src = "${src}/server/web";
    hash = "sha256-yKUCnVDeLTESq7aCU55OIe26UzgAmBeXSD6aRHrfRaA=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    pkg-config
  ];
  buildInputs = [ openssl ];
  # The openssl crate's `vendored` feature would otherwise build OpenSSL from source.
  env.OPENSSL_NO_VENDOR = "1";

  # The tests' HTTP client refuses to start without CA certificates, though it only
  # talks to the loopback server under test.
  nativeCheckInputs = [ cacert ];

  preBuild = ''
    (cd server/web && npm run build)
  '';

  passthru = { inherit extension; };

  meta = {
    description = "Control running pi sessions from a phone or browser";
    homepage = "https://github.com/mipsel64/pi-remote-control";
    license = lib.licenses.mit;
    mainProgram = "prc";
  };
}
