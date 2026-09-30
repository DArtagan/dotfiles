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
  ketch = pkgs.callPackage ../../pkgs/ketch/package.nix { };
in
{
  home = {
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
        }
      );

      # pi-quotas' feature toggles (`/quotas:settings` writes here too). Its presence
      # also stops pi-quotas from posting its first-run notice into the conversation.
      piQuotasSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-quotas-managed" ".pi/agent/extensions/quotas.json" {
          quotasCommand = true; # /quotas
          providerCommands = true; # /anthropic:quotas etc.
          usageStatus = true; # 5h/7d plan windows in the footer
          tokenStatus = false; # OpenCode Go spend tracking, which we don't use
          quotaWarnings = true;
        }
      );
    };
  };
}
