{
  chromium,
  installAgentSkills,
  ketch,
  lib,
  makeWrapper,
  runCommand,
}:

# nixpkgs' ketch, plus its agent skill (which nixpkgs doesn't install) in
# share/skills/ketch/ketch, where nixpkgs' installAgentSkills puts a package's skills,
# and a wrapper. Leaves out nixpkgs' `readtest`, a debugging tool from the same repo.
runCommand "ketch-${ketch.version}"
  {
    nativeBuildInputs = [
      installAgentSkills
      makeWrapper
    ];
    pname = "ketch";
    inherit (ketch) version;
    meta = ketch.meta // {
      homepage = "https://ketch.run";
    };
  }
  ''
    installSkill ${ketch.src}/skills/ketch
    # ketch renders JS-shell pages in a browser; `ketch browser install` would download
    # a Chromium that NixOS can't run. KETCH_* env outranks ketch's config file, so
    # `ketch config set browser` has no effect. Updates come through nixpkgs, so its
    # self-update notices are noise.
    makeWrapper ${lib.getExe ketch} $out/bin/ketch \
      --set-default KETCH_BROWSER ${lib.getExe chromium} \
      --set-default KETCH_NO_UPDATE_NOTIFIER 1
  ''
