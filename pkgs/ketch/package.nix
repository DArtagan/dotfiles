{
  buildGoModule,
  chromium,
  fetchFromGitHub,
  lib,
  makeWrapper,
  versionCheckHook,
}:

# Web search, OSS code search, library docs, and scraping for agents. Modeled on
# nixpkgs' pkgs/by-name/ke/ketch, plus the skill and the wrapper below.
#
# TODO: Switch to pkgs.ketch once nixpkgs catches up to this version (it has 0.14.0;
# NixOS/nixpkgs#564213 bumps it to 0.17.0). nixpkgs doesn't install the skill, so
# take it from `pkgs.ketch.src + "/skills/ketch"` and keep the wrapper, e.g.
# with symlinkJoin.
buildGoModule (finalAttrs: {
  pname = "ketch";
  version = "0.18.1";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "1broseidon";
    repo = "ketch";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vXSYQJBZ0Eypy3S0qvJUEEk9SZnnIWmQ5DU3TGyuwfk=";
  };

  vendorHash = "sha256-NqZlxCbXfH4OJQGEVQwA6uu5LLlKDmwGYDRM6V8U/+4=";

  nativeBuildInputs = [ makeWrapper ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/1broseidon/ketch/cmd.version=v${finalAttrs.version}"
  ];

  # Its golden file pins the User-Agent of an unversioned ("dev") build.
  checkFlags = [ "-skip=^TestRegistryConfigCompatibilityGolden$" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";

  postInstall = ''
    mkdir -p $out/share/ketch
    cp -r skills $out/share/ketch/
  '';

  # ketch renders JS-shell pages in a browser; `ketch browser install` would download a
  # Chromium that NixOS can't run. KETCH_* env outranks ketch's config file, so
  # `ketch config set browser` has no effect. Updates come through this file, so its
  # self-update notices are noise.
  postFixup = ''
    wrapProgram $out/bin/ketch \
      --set-default KETCH_BROWSER ${lib.getExe chromium} \
      --set-default KETCH_NO_UPDATE_NOTIFIER 1
  '';

  meta = {
    description = "Stateless CLI for web search, code search, library docs, and scraping, built for AI agents";
    homepage = "https://ketch.run";
    changelog = "https://github.com/1broseidon/ketch/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "ketch";
  };
})
