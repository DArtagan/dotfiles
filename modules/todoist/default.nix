# Doist's `td` CLI and its agent skill for pi. Home-manager module, imported by
# home.nix. Logging in is a manual step on each host; see ./README.md.
{ pkgs, ... }:
let
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
    packages = [ pkgs.todoist-cli ];

    # pi finds skills here as well as in settings.json `skills`, which modules/pi owns.
    file.".pi/agent/skills/todoist-cli".source = skill;
  };
}
