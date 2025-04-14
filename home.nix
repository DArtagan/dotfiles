{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      awscli2
      bottom
      curl
      devenv
      graphviz
      home-manager
      fluxcd
      fzf
      jq
      magic-wormhole
      nix-output-monitor
      nixos-rebuild
      pgcli
      pstree
      rclone
      ripgrep
      tree
      zed-editor
    ];
    shell.enableShellIntegration = true;
  };

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    zed-editor = {
      enable = true;
      extensions = [
        "nix"
        "toml"
        "make"
        "zed-legacy-themes"
      ];

      # everything inside of these brackets are Zed options - saved to settings.json
      userSettings = {
        features = {
          edit_prediction_provider = "zed";
        };

        assistant = {
          enabled = true;
          version = "2";
          default_open_ai_model = null;
          #default_model = {
          #  provider = "ollama";
          #  model = "codegemma:7b";
          #};
        };

        language_models = {
          ollama = {
            apiUrl = "http://localhost:11434";
            availableModels = [
              {
                name = "codestral";
                displayName = "codestral 22b";
                maxTokens = 262144;
              }
              {
                name = "qwen2.5-coder:32b";
                displayName = "qwen2.5-coder:32b";
                maxTokens = 32768;
              }
              {
                name = "codegemma:7b";
                displayName = "codegemma:7b";
                maxTokens = 8192;
              }
            ];
          };
        };

        hour_format = "hour24";
        auto_update = false;

        terminal = {
          copy_on_select = true;
          detect_venv = {
            on = {
              directories = [
                ".env"
                "env"
                ".venv"
                "venv"
              ];
              activate_script = "default";
            };
          };
          font_family = "Hack Nerd Font";
          font_size = null;
          button = false;
        };

        lsp = {
          nix = {
            binary = {
              path_lookup = true;
            };
          };
          pyright = {
            binary = {
              path_lookup = true;
            };
          };
        };

        tab_size = 4;

        languages = {
          nix = {
            tab_size = 2;
          };
        };

        load_direnv = "shell_hook";
        show_completions_on_input = true;
        vim_mode = true;

        theme = {
          mode = "system";
          light = "Zed Legacy: Solarized Light";
          dark = "Zed Legacy: Solarized Dark";
        };
        show_whitespaces = "none";
        indent_guides = {
          enabled = true;
          coloring = "indent_aware";
        };
        ui_font_size = 14;
        buffer_font_size = 12;
        #buffer_font_size = 14;
        #buffer_font_family = "Hack Nerd Font";
        #buffer_font_weight = 400;
        cursor_blink = false;
        relative_line_numbers = true;
      };
      userKeymaps = [
        {
          context = "Dock || Editor";
          bindings = {
            "ctrl-a h" = "workspace::ActivatePaneLeft";
            "ctrl-a l" = "workspace::ActivatePaneRight";
            "ctrl-a k" = "workspace::ActivatePaneUp";
            "ctrl-a j" = "workspace::ActivatePaneDown";
          };
        }
      ];
    };
  };
}
