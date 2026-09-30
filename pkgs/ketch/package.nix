{
  buildGoModule,
  chromium,
  fetchFromGitHub,
  lib,
  makeWrapper,
}:

# Web search, OSS code search, library docs, and scraping for agents. Not in nixpkgs.
buildGoModule (finalAttrs: {
  pname = "ketch";
  version = "0.18.1";

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
    license = lib.licenses.mit;
    mainProgram = "ketch";
  };
})
