{
  lib,
  pkgs,
  ...
}:
let
  # pi and its extensions write runtime state into the same JSON files we configure.
  mergeJsonInto = import ../../lib/merge-json-into.nix { inherit pkgs; };
in
{
  home = {
    packages = [ pkgs.pi-coding-agent ];

    activation = {
      piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-settings-managed" ".pi/agent/settings.json" {
          defaultProvider = "claude-bridge";
          defaultModel = "claude-opus-5-5";
          defaultThinkingLevel = "high";
          theme = "light";
          # Declares the extension; pi still installs/updates it into ~/.pi/agent/npm
          # (`pi update --extensions`).
          packages = [ "npm:pi-claude-bridge" ];
        }
      );

      # pi-claude-bridge would otherwise spawn the Agent SDK's bundled generic-linux
      # `claude`, which NixOS can't run. Point it at ours.
      piClaudeBridgeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-claude-bridge-managed" ".pi/agent/claude-bridge.json" {
          provider.pathToClaudeCodeExecutable = lib.getExe pkgs.claude-code;
        }
      );
    };
  };
}
