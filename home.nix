{ lib, pkgs, ... }:
{
  home = {
    activation.configure-tide = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.fish}/bin/fish -c "tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Sparse --icons='Few icons' --transient=No"
    '';

    packages = with pkgs; [
      awsume
      curl
      devenv
      graphviz
      #fishPlugins.done
      #fishPlugins.fzf-fish
      #fishPlugins.tide
      fluxcd
      magic-wormhole
      nix-output-monitor
      nixos-rebuild
      nodejs # For vim CoC
      pgcli
      pstree
      rclone
      tree
      uv
    ];
    shell.enableShellIntegration = true;
  };

  programs = {
    awscli.enable = true;
    bottom.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fish = {
      enable = true;
      functions = {
        ua-drop-caches = ''
          function ua-drop-caches --wraps='sudo paccache -rk3; sudo aura -Sc --noconfirm' --description 'alias ua-drop-caches sudo paccache -rk3; sudo aura -Sc --noconfirm'
            sudo paccache -rk3; sudo aura -Sc --noconfirm $argv
          end
        '';
        ua-update-all = ''
          function ua-update-all --wraps=export\ TMPFILE=\"\$\(mktemp\)\"\;\ \\\n\ \ sudo\ true\;\ \\\n\ \ rate-mirrors\ --save=\$TMPFILE\ manjaro\ --max-delay=21600\ \\\n\ \ \ \ \&\&\ sudo\ mv\ /etc/pacman.d/mirrorlist\ /etc/pacman.d/mirrorlist-backup\ \\\n\ \ \ \ \&\&\ sudo\ mv\ \$TMPFILE\ /etc/pacman.d/mirrorlist\ \\\n\ \ \ \ \&\&\ ua-drop-caches\ \\\n\ \ \ \ \&\&\ sudo\ aura\ -Sy\ --noconfirm\ archlinux-keyring\ \\\n\ \ \ \ \&\&\ sudo\ aura\ -Syyu\ --noconfirm --description alias\ ua-update-all\ export\ TMPFILE=\"\$\(mktemp\)\"\;\ \\\n\ \ sudo\ true\;\ \\\n\ \ rate-mirrors\ --save=\$TMPFILE\ manjaro\ --max-delay=21600\ \\\n\ \ \ \ \&\&\ sudo\ mv\ /etc/pacman.d/mirrorlist\ /etc/pacman.d/mirrorlist-backup\ \\\n\ \ \ \ \&\&\ sudo\ mv\ \$TMPFILE\ /etc/pacman.d/mirrorlist\ \\\n\ \ \ \ \&\&\ ua-drop-caches\ \\\n\ \ \ \ \&\&\ sudo\ aura\ -Sy\ --noconfirm\ archlinux-keyring\ \\\n\ \ \ \ \&\&\ sudo\ aura\ -Syyu\ --noconfirm
            export TMPFILE="$(mktemp)"; \
            sudo true; \
            rate-mirrors --save=$TMPFILE manjaro --max-delay=21600 \
              && sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup \
              && sudo mv $TMPFILE /etc/pacman.d/mirrorlist \
              && ua-drop-caches \
              && sudo aura -Sy --noconfirm archlinux-keyring \
              && sudo aura -Syyu --noconfirm $argv
          end
        '';
      };
      plugins = [
        {
          name = "done";
          inherit (pkgs.fishPlugins.done) src;
        }
        {
          name = "fzf-fish";
          inherit (pkgs.fishPlugins.fzf-fish) src;
        }
        {
          name = "tide";
          inherit (pkgs.fishPlugins.tide) src;
        }
        {
          name = "fish-ai";
          src = pkgs.fetchFromGitHub {
            owner = "Realiserad";
            repo = "fish-ai";
            rev = "v1.7.0";
            sha256 = "GnUBPkZZ0mfMUPnk62jxrAMGPFW8YxChhFBUBsdEwLA=";
          };
        }
      ];
      shellAliases = {
        awsume = "source (which awsume.fish)";
      };
      shellInit = ''
        	set -g -x PIP_REQUIRE_VIRTUALENV true

                # Added by OrbStack: command-line tools and integration
                # This won't be added again if you remove it.
        	source ~/.orbstack/shell/init2.fish 2>/dev/null || :
      '';
    };
    fzf.enable = true;
    home-manager.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
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
