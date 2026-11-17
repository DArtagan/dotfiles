{
  installAgentSkills,
  runCommand,
  symlinkJoin,
  todoist-cli,
}:

let
  # td writes its own skill, matched to its version. It needs no network or login.
  skill =
    runCommand "todoist-cli-skill-${todoist-cli.version}"
      {
        nativeBuildInputs = [
          installAgentSkills
          todoist-cli
        ];
        pname = "todoist-cli";
      }
      ''
        export HOME=$TMPDIR
        cd $TMPDIR
        td skill install universal --local
        installSkill .agents/skills/todoist-cli
      '';
in
# nixpkgs' todoist-cli (`td`), plus its agent skill (which nixpkgs doesn't install) in
# share/skills/todoist-cli/todoist-cli, where nixpkgs' installAgentSkills puts a
# package's skills.
symlinkJoin {
  name = "todoist-cli-${todoist-cli.version}";
  pname = "todoist-cli";
  inherit (todoist-cli) version;
  paths = [
    todoist-cli
    skill
  ];
  meta = todoist-cli.meta // {
    mainProgram = "td";
  };
  passthru = { inherit skill; };
}
