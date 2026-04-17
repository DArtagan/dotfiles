_: {
  programs = {
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
        edit_predictions = {
          provider = "zed";
        };

        agent = {
          default_model = {
            provider = "ollama";
            model = "qwen2.5-coder:32b";
          };
          inline_assistant_model = {
            provider = "ollama";
            model = "qwen2.5-coder:32b";
          };
          commit_message_model = {
            provider = "ollama";
            model = "qwen2.5-coder:32b";
          };
          thread_summary_model = {
            provider = "ollama";
            model = "qwen2.5-coder:32b";
          };
        };

        language_models = {
          ollama = {
            api_url = "http://thenixbeast.forge.local:11434";
            available_models = [
              {
                name = "codestral";
                display_name = "codestral 22b";
                max_tokens = 262144;
              }
              {
                name = "qwen2.5-coder:32b";
                display_name = "qwen2.5-coder:32b";
                max_tokens = 32768;
              }
              {
                name = "codegemma:7b";
                display_name = "codegemma:7b";
                max_tokens = 8192;
              }
            ];
          };
        };

        hour_format = "hour24";
        auto_update = false;

        terminal = {
          shell = {
            program = "fish";
          };
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
          # TODO: stylix, remove
          #font_family = "Hack Nerd Font";
          #font_size = null;
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

        # TODO: stylix, remove
        #theme = {
        #  mode = "system";
        #  light = "Zed Legacy: Solarized Light";
        #  dark = "Zed Legacy: Solarized Dark";
        #};
        show_whitespaces = "none";
        indent_guides = {
          enabled = true;
          coloring = "indent_aware";
        };
        # TODO: stylix, remove
        #ui_font_size = 14;
        #buffer_font_size = 12;
        #buffer_font_size = 14;
        #buffer_font_family = "Hack Nerd Font";
        #buffer_font_weight = 400;
        cursor_blink = false;
        relative_line_numbers = "enabled";
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
