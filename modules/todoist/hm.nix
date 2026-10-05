# Home-manager half of the todoist module: Doist's `td` CLI and its agent skill for
# pi. Imported by home.nix, so every home configuration gets it.
#
# Where ./default.nix (NixOS) is also imported, it sets tokenFile to the decrypted
# sops secret and `td` logs in from that. Elsewhere `td` falls back to its own
# `td auth login`. See ./README.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  token = config.my.todoist.tokenFile;

  # td prefers TODOIST_API_TOKEN over its own keyring login, so no `td auth login`
  # is needed. The token is read per invocation rather than exported into the
  # session, so it isn't sitting in every process's environment.
  td =
    if token == null then
      pkgs.todoist-cli
    else
      pkgs.symlinkJoin {
        name = "td-${pkgs.todoist-cli.version}";
        paths = [ pkgs.todoist-cli ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/td --run '
            if [ -r ${token} ]; then export TODOIST_API_TOKEN="$(< ${token})"; fi
          '
        '';
      };

  # td writes its own skill, matched to its version. It needs no network or login.
  skill =
    pkgs.runCommand "todoist-cli-skill-${pkgs.todoist-cli.version}"
      {
        nativeBuildInputs = [ pkgs.todoist-cli ];
      }
      ''
        export HOME=$TMPDIR
        cd $TMPDIR
        td skill install universal --local
        cp -r .agents/skills/todoist-cli $out
      '';
in
{
  options.my.todoist.tokenFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/run/secrets/todoist/api_token";
    description = ''
      File holding a Todoist API token for `td` to log in with. Set by ./default.nix
      on NixOS hosts that import it. When null, `td` uses its own `td auth login`.
    '';
  };

  config.home = {
    packages = [ td ];

    file = {
      # pi finds skills here as well as in settings.json `skills`, which modules/pi owns.
      ".pi/agent/skills/todoist-cli".source = skill;
    }
    // lib.optionalAttrs (token != null) {
      # Where scripts outside td (e.g. life-gistics' audit and export) read the token.
      ".config/todoist/token".source = config.lib.file.mkOutOfStoreSymlink token;
    };
  };
}
