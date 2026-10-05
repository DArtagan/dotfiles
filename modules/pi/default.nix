{
  lib,
  pkgs,
  ...
}:
let
  # pi and its extensions write runtime state into the same JSON files we configure.
  mergeJsonInto = import ../../lib/merge-json-into.nix { inherit pkgs; };
  pi-claude-bridge = pkgs.callPackage ../../pkgs/pi-claude-bridge/package.nix { };
  pi-quotas = pkgs.callPackage ../../pkgs/pi-quotas/package.nix { };
  pine-of-glass = pkgs.callPackage ../../pkgs/pine-of-glass/package.nix { };
  rpiv-ask-user-question = pkgs.callPackage ../../pkgs/rpiv-ask-user-question/package.nix { };
  ketch = pkgs.callPackage ../../pkgs/ketch/package.nix { };
in
{
  home = {
    # pi only rewrites this file to migrate old action names, so it can be a symlink.
    # Ctrl+Shift+Enter reaches pi through the Alacritty binding in home.nix.
    file = {
      ".pi/agent/keybindings.json".text = builtins.toJSON {
        "app.message.followUp" = [
          "ctrl+shift+enter"
          "alt+enter"
        ];
      };
      # pine-of-glass's latency extension is off unless this says otherwise. It only
      # reads the file.
      ".pi/agent/pi-meantime.json".text = builtins.toJSON { enabled = true; };
    };

    packages = [
      pkgs.pi-coding-agent
      ketch
    ];

    activation = {
      piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-settings-managed" ".pi/agent/settings.json" {
          defaultProvider = "claude-bridge";
          defaultModel = "claude-opus-5-5";
          defaultThinkingLevel = "high";
          theme = "light";
          # Loaded in place from the store, so `pi update --extensions` leaves these
          # alone; bump them in pkgs/.
          packages = [
            "${pi-claude-bridge}/lib/node_modules/pi-claude-bridge"
            "${pi-quotas}"
            "${pine-of-glass}"
            "${rpiv-ask-user-question}"
          ];
          extensions = [
            "${./exit.ts}"
            "${./terminal-cursor.ts}"
          ];
          # Web search and fetch, through the ketch CLI. See README.md.
          skills = [ "${ketch}/share/ketch/skills/ketch" ];
        }
      );

      # pi-claude-bridge would otherwise spawn the Agent SDK's bundled generic-linux
      # `claude`, which NixOS can't run. Point it at ours.
      piClaudeBridgeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-claude-bridge-managed" ".pi/agent/claude-bridge.json" {
          provider.pathToClaudeCodeExecutable = lib.getExe pkgs.claude-code;
          # The AskClaude tool, which lets other providers' models delegate to Claude
          # Code. claude-bridge's own models don't get it.
          askClaude.enabled = true;
        }
      );
    };
  };
}
