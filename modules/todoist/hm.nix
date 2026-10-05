# Home-manager half of the todoist module: Doist's `td` CLI, authenticated from
# the sops-managed token, and its agent skill for pi.
#
# Pairs with ./default.nix, which decrypts the token. See ./README.md.
{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  token = osConfig.sops.secrets."todoist/api_token".path;

  # td prefers TODOIST_API_TOKEN over its own keyring login, so no `td auth login`
  # is needed. The token is read per invocation rather than exported into the
  # session, so it isn't sitting in every process's environment.
  td = pkgs.symlinkJoin {
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
  home = {
    packages = [ td ];

    file = {
      # pi finds skills here as well as in settings.json `skills`, which modules/pi owns.
      ".pi/agent/skills/todoist-cli".source = skill;
      # Where scripts outside td (e.g. life-gistics' audit and export) read the token.
      ".config/todoist/token".source = config.lib.file.mkOutOfStoreSymlink token;
    };
  };
}
