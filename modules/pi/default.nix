{
  config,
  lib,
  pkgs,
  ...
}:
let
  # pi and its extensions write runtime state into the same JSON files we configure.
  mergeJsonInto = import ../../lib/merge-json-into.nix { inherit pkgs; };
  pi-claude-bridge = pkgs.callPackage ../../pkgs/pi-claude-bridge/package.nix { };
  pi-autoresearch = pkgs.callPackage ../../pkgs/pi-autoresearch/package.nix { };
  pi-quotas = pkgs.callPackage ../../pkgs/pi-quotas/package.nix { };
  pine-of-glass = pkgs.callPackage ../../pkgs/pine-of-glass/package.nix { };
  rpiv-ask-user-question = pkgs.callPackage ../../pkgs/rpiv-ask-user-question/package.nix { };
  ketch = pkgs.callPackage ../../pkgs/ketch/package.nix { };

  # Agents get plain `git diff`: difftastic's side-by-side output is several times the
  # size of a unified diff, and it bypasses textconv (e.g. masked SOPS diffs). git can't
  # unset diff.external from the environment (an empty value fails to run), so pi gets
  # GIT_CONFIG_GLOBAL pointing at a copy of the global config without it. HM renders
  # iniContent first, then includes and list-form settings; swapping only the iniContent
  # part keeps those.
  gitIni = config.programs.git.iniContent;
  agentGitConfig =
    lib.replaceStrings
      [ (lib.generators.toGitINI gitIni) ]
      [
        (lib.generators.toGitINI (gitIni // { diff = removeAttrs gitIni.diff [ "external" ]; }))
      ]
      config.xdg.configFile."git/config".text;
  agentGitConfigPath = "${config.xdg.configHome}/git/config-agent";
  # Only bin/pi: symlinkJoin would mirror all of node_modules as symlinks (~7 MiB).
  pi =
    pkgs.runCommand pkgs.pi-coding-agent.name
      {
        inherit (pkgs.pi-coding-agent) meta;
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        makeWrapper ${lib.getExe pkgs.pi-coding-agent} $out/bin/pi \
          --set GIT_CONFIG_GLOBAL ${agentGitConfigPath}
      '';
in
{
  imports = [ ./google.nix ];

  assertions = [
    {
      assertion = !lib.hasInfix "\texternal = " agentGitConfig;
      message = "modules/pi: diff.external is still in the agents' git config.";
    }
  ];

  xdg.configFile."git/config-agent".text = agentGitConfig;

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
      pi
      ketch
    ];

    activation = {
      piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mergeJsonInto "pi-settings-managed" ".pi/agent/settings.json" {
          defaultProvider = "claude-bridge";
          defaultModel = "claude-opus-5-5";
          defaultThinkingLevel = "high";
          # Draw only the terminal's cursor, not pi's reverse-video one, so it hollows
          # in an unfocused Alacritty window and hides in inactive tmux panes.
          showHardwareCursor = true;
          # Loaded in place from the store, so `pi update --extensions` leaves these
          # alone; bump them in pkgs/.
          packages = [
            "${pi-claude-bridge}/lib/node_modules/pi-claude-bridge"
            "${pi-quotas}"
            "${pine-of-glass}"
            "${rpiv-ask-user-question}"
            "${pi-autoresearch}"
          ];
          extensions = [
            "${./copy-code.ts}"
            "${./exit.ts}"
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
          # Refresh an idle session's one-hour prompt cache for 12 hours after its last
          # turn (local patch, pkgs/pi-claude-bridge/cache-warming.patch). See README.md.
          cacheWarming = {
            enabled = true;
            idleWindowMinutes = 720;
            minPromptTokens = 20000;
          };
        }
      );
    };
  };
}
