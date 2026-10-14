{
  gogcli,
  lib,
  makeWrapper,
  # A safety profile (https://gogcli.sh/safety-profiles.html): which commands may run,
  # and flag values to lock.
  profile,
  # Variables to set in a `gog` wrapper, e.g. GOG_CLIENT to give the profile its own
  # token.
  env ? { },
}:

# gogcli with a safety profile compiled in, which flags, env vars and config can't
# loosen. Does what upstream's build-safe.sh does, inside nixpkgs' build.
gogcli.overrideAttrs (old: {
  pname = "gog-safe";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];

  tags = (old.tags or [ ]) ++ [ "safety_profile" ];

  preBuild = (old.preBuild or "") + ''
    go run ./cmd/bake-safety-profile ${profile} internal/cmd/safety_profile_baked_gen.go
  '';
  # The vendoring step runs preBuild too, before there's a vendor directory to run from.
  passthru = old.passthru // {
    overrideModAttrs = lib.composeExtensions old.passthru.overrideModAttrs (
      _: _: { preBuild = old.preBuild or ""; }
    );
  };

  postInstall =
    (old.postInstall or "")
    + lib.optionalString (env != { }) ''
      wrapProgram $out/bin/gog ${
        lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env)
      }
    '';
})
