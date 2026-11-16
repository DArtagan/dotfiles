{
  config,
  lib,
  pkgs,
  ...
}:
# pier: pi on Pi Durable. One daemon per host owns every conversation, and `pier` in any
# pane attaches to it. Imported per host; see README.md, "pier".
let
  pier = pkgs.callPackage ../../pkgs/pier/package.nix { };
in
{
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
}
