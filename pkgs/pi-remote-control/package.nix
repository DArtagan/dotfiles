{
  aws-lc,
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
  version = "0.1.10";

  src = fetchFromGitHub {
    owner = "mipsel64";
    repo = "pi-remote-control";
    tag = "v${version}";
    hash = "sha256-Y/jUtMSDzQATfgCFdY9ps1x+nrbEwB37PpIVnQAZYVA=";
  };

  # pi loads the extension from the store (settings.json `packages`). Its only runtime
  # dependency is ws, at the version upstream's lockfile pins; the rest of that
  # lockfile is dev tooling (pi itself, Playwright).
  ws = fetchurl {
    url = "https://registry.npmjs.org/ws/-/ws-8.22.0.tgz";
    hash = "sha512-Ydggc987+RO0AnWtZ/7Wq9FtNvcrL1b/RO0ud9mWjUPgDrsAAwQSF51sm2hm1XofbU/4jkpGEsLFsZZxU+1DOg==";
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
  cargoHash = "sha256-r0yza3an2USBJ5uPU49lq18oJgJsaU/lQm7EmxGZyd8=";

  # The web UI is built first and embedded into the binary (include_dir!).
  npmRoot = "server/web";
  npmDeps = fetchNpmDeps {
    name = "pi-remote-control-${version}-npm-deps";
    src = "${src}/server/web";
    hash = "sha256-s40zlQkI/5Ojj2G7mPIxo2Gp6c3HZzYvpo8IXfcKNYE=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    pkg-config
  ];
  # cargoSetupHook sets AWS_LC_SYS_USE_SYSTEM, so aws-lc-sys links nixpkgs' AWS-LC.
  buildInputs = [
    aws-lc
    openssl
  ];
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
