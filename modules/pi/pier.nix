{
  config,
  lib,
  pkgs,
  ...
}:
# pier: pi on Pi Durable. One daemon per host owns every conversation, and `pier` in any
# pane attaches to it. Imported per host; see README.md, "pier".
let
  cfg = config.programs.pier;
  pier = pkgs.callPackage ../../pkgs/pier/package.nix { };
  tools = import ./tools.nix { inherit pkgs; };
in
{
  options.programs.pier.skills = lib.mkOption {
    type = with lib.types; listOf path;
    description = ''
      The skill directories pier offers its agents, besides each project's own
      `.agents/skills` and `.pi/skills`: each one skill (holding SKILL.md) or a directory
      of them, such as a package's share/skills/<pname>. Passed as `PIER_SKILLS`; read
      when the daemon starts. pier reads nothing of pi's for skills.
    '';
  };

  config = {
    # The tools' skills (tools.nix): web search and fetch through ketch, Google Calendar
    # through gog, Todoist through td. Listed here, not taken from pi's settings, so
    # pier's configuration stands on its own.
    programs.pier.skills = [
      "${tools.ketch}/share/skills/ketch"
      "${tools.gog}/share/skills/gog"
      "${tools.todoist-cli}/share/skills/todoist-cli"
    ];

    home.packages = [ pier ];

    systemd.user.services.pier = {
      Unit = {
        Description = "pier: pi on Pi Durable, one daemon for this host's conversations";
        # A restart interrupts every pane's run, and a tool not safe to rerun (bash) comes
        # back to the model as interrupted. So a switch leaves a running daemon on its old
        # version; restart it when idle: `systemctl --user restart pier`.
        X-SwitchMethod = "keep-old";
      };
      Service = {
        ExecStart = "${lib.getExe pier} daemon";
        Environment = [
          # pi-claude-code runs `claude` from the PATH otherwise.
          "PI_CLAUDE_CODE_COMMAND=${lib.getExe pkgs.claude-code}"
          # Each conversation's tools get the environment of the pane that last attached,
          # laid over this one; this PATH is for the daemon and Claude Code themselves.
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
          # Panes don't set this (only the wrapped `pi` does), so tools inherit it from here.
          "GIT_CONFIG_GLOBAL=${config.home.homeDirectory}/${config.xdg.configFile."git/config-agent".target}"
          # The skills it offers. A changed list reaches the daemon at its next restart.
          "PIER_SKILLS=${lib.concatStringsSep ":" cfg.skills}"
        ];
        # Durable runs each tool, and pi-claude-code each Claude Code, in a process group of
        # its own, so only the cgroup kill reaps them when the daemon stops or dies.
        # systemd's default; spelled out so nothing weakens it.
        KillMode = "control-group";
        # Durable resumes every conversation's work when it comes back.
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
