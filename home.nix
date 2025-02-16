{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      devenv
      home-manager
      nom
      zed
    ];
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
      ];

      # everything inside of these brackets are Zed options - saved to settings.json
      userSettings = {
        assistant = {
          enabled = true;
          version = "2";
          default_open_ai_model = null;
          default_model = {
            provider = "zed.dev";
            model = "claude-3-5-sonnet-latest";
          };
          # inline_alternatives = [
          #     {
          #         provider = "copilot_chat";
          #         model = "gpt-3.5-turbo";
          #     }
          # ];
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

        languages =
          {
          };

        load_direnv = "shell_hook";
        show_completions_on_input = true;
        vim_mode = true;

        theme = {
          mode = "system";
          light = "Solarized Light";
          dark = "Solarized Dark";
        };
        #show_whitespaces = "all" ;
        ui_font_size = 14;
        buffer_font_size = 12;
      };
    };
  };
}
