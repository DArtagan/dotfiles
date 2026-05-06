{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    modules/qutebrowser
    modules/vim
    modules/zed
  ];

  # Idea: put all the personal files and sensitive values in a mountable volume.  So the computer can be used casually be default, and if keyboard, unlocked for work.

  # File contents techniques:
  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;
  #
  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };
  #
  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';
  fonts.fontconfig.enable = true;

  home = {
    # If erroring on first build, this activation line is preventing tide from getting installed.  Comment out this stanza, nixos-rebuild, then uncomment.
    activation.configure-tide = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.fish}/bin/fish -c "tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Sparse --icons='Few icons' --transient=No"
    '';

    packages = with pkgs; [
      broot
      calibre
      claude-code
      curl
      deluge # bittorrent
      devenv
      dnsutils # `dig` + `nslookup`
      gh
      gparted
      graphviz
      inetutils # ping
      inxi # show computer specs (sadly unmaintained since 2014)
      ldns # replacement of `dig`, it provides the command `drill`
      lsof # list open files
      nerd-fonts.hack
      magic-wormhole
      mumble
      nix-output-monitor
      nix-tree # explore the package dependency tree, what derivation is using what
      nixos-rebuild
      nodejs # For vim CoC
      pciutils # lspci
      pstree
      python313Packages.psutil # For vim Recover.vim
      qbz
      rclone
      # tree  # Use `broot` instead, eventually remove this line if you prefer it
      ueberzugpp # Image preview for yazi
      unzip
      usbutils # lsusb
      uv
      worktrunk
      xz
      zip
      zstd
    ];
    shell.enableShellIntegration = true;
  };

  xdg.configFile."worktrunk/config.toml".text = ''
    # Worktrunk user config — global defaults for all repos
    worktree-path = "{{ repo_path }}/.worktrees/{{ branch | sanitize }}"

    [aliases]
    move-changes = ''''
    if git diff --quiet HEAD && test -z "$(git ls-files --others --exclude-standard)"; then
      wt switch --create {{ to }} --execute="{{ args }}"
    else
      git stash push --include-untracked --quiet
      wt switch --create {{ to }} --execute="git stash pop --index; {{ args }}"
    fi
    ''''
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "firefox.desktop" ];
      "x-scheme-handler/claude-cli" = [ "claude-code-url-handler.desktop" ];
    };
  };

  home.file.".claude/statusline-command.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Claude Code statusLine command — styled after tide prompt configuration
      # Left prompt items: pwd, git | Right prompt items: status, cmd_duration, context,
      #   jobs, direnv, terraform, nix_shell, kubectl
      # Plus Claude-specific: model, context window usage, session limit countdown

      input=$(cat)

      # --- Claude Code data ---
      cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
      model=$(echo "$input" | jq -r '.model.display_name // empty')
      used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
      five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
      five_hour_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
      seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

      # --- pwd (shorten $HOME to ~) ---
      short_pwd="''${cwd/#$HOME/~}"

      # --- git branch + dirty indicator ---
      git_info=""
      if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
          branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                   || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
          if [ -n "$branch" ]; then
              dirty=""
              if ! git -C "$cwd" diff --quiet 2>/dev/null \
                 || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
                  dirty="*"
              fi
              untracked=""
              if [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
                  untracked="?"
              fi
              git_info=$' on \033[35m'"''${branch}''${dirty}''${untracked}"$'\033[0m'
          fi
      fi

      # --- context (user@host) ---
      context_info="$(whoami)@$(hostname -s)"

      # --- terraform workspace ---
      tf_workspace=""
      if [ -f "$cwd/.terraform/environment" ]; then
          ws=$(cat "$cwd/.terraform/environment" 2>/dev/null)
          if [ -n "$ws" ] && [ "$ws" != "default" ]; then
              tf_workspace=$' \033[35mtf:'"''${ws}"$'\033[0m'
          fi
      fi

      # --- nix shell indicator ---
      nix_info=""
      if [ -n "$IN_NIX_SHELL" ] || [ -n "$DEVENV_ROOT" ]; then
          nix_info=$' \033[34mnix\033[0m'
      fi

      # --- kubectl context ---
      kube_info=""
      if command -v kubectl > /dev/null 2>&1; then
          kube_ctx=$(kubectl config current-context 2>/dev/null)
          if [ -n "$kube_ctx" ]; then
              kube_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
              kube_namespace="''${kube_namespace:-default}"
              kube_info=$' \033[36mk8s:'"''${kube_ctx}/''${kube_namespace}"$'\033[0m'
          fi
      fi

      # --- model ---
      model_info=""
      if [ -n "$model" ]; then
          model_info=$' \033[33m'"''${model}"$'\033[0m'
      fi

      # --- context window usage ---
      ctx_info=""
      if [ -n "$used_pct" ]; then
          # Colour: green < 50%, yellow < 80%, red >= 80%
          used_int=$(printf '%.0f' "$used_pct")
          if [ "$used_int" -ge 80 ]; then
              color=$'\033[31m'
          elif [ "$used_int" -ge 50 ]; then
              color=$'\033[33m'
          else
              color=$'\033[32m'
          fi
          ctx_info=$' '"''${color}ctx:''${used_int}%"$'\033[0m'
      fi

      # --- rate limits ---
      rate_info=""
      if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
          rate_parts=""
          if [ -n "$five_hour_pct" ]; then
              five_int=$(printf '%.0f' "$five_hour_pct")
              if [ "$five_int" -ge 80 ]; then
                  five_color=$'\033[31m'
              elif [ "$five_int" -ge 50 ]; then
                  five_color=$'\033[33m'
              else
                  five_color=$'\033[32m'
              fi
              # Compute time until reset
              reset_str=""
              if [ -n "$five_hour_resets" ]; then
                  now=$(date +%s)
                  secs_left=$(( five_hour_resets - now ))
                  if [ "$secs_left" -gt 0 ]; then
                      mins_left=$(( secs_left / 60 ))
                      hrs_left=$(( mins_left / 60 ))
                      mins_rem=$(( mins_left % 60 ))
                      if [ "$hrs_left" -gt 0 ]; then
                          reset_str=" (''${hrs_left}h''${mins_rem}m)"
                      else
                          reset_str=" (''${mins_left}m)"
                      fi
                  fi
              fi
              rate_parts="''${five_color}5h:''${five_int}%''${reset_str}"$'\033[0m'
          fi
          if [ -n "$seven_day_pct" ]; then
              seven_int=$(printf '%.0f' "$seven_day_pct")
              if [ "$seven_int" -ge 80 ]; then
                  seven_color=$'\033[31m'
              elif [ "$seven_int" -ge 50 ]; then
                  seven_color=$'\033[33m'
              else
                  seven_color=$'\033[32m'
              fi
              if [ -n "$rate_parts" ]; then
                  rate_parts="''${rate_parts} ''${seven_color}7d:''${seven_int}%"$'\033[0m'
              else
                  rate_parts="''${seven_color}7d:''${seven_int}%"$'\033[0m'
              fi
          fi
          rate_info=" ''${rate_parts}"
      fi

      # --- worktrunk statusline ---
      wt_info=""
      if command -v wt > /dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
          wt_line=$(cd "$cwd" && wt list statusline --format=claude-code 2>/dev/null)
          if [ -n "$wt_line" ]; then
              wt_info="$wt_line"
          fi
      fi

      # --- assemble ---
      printf "\033[34m%s\033[0m%s" "$short_pwd" "$git_info"
      printf " \033[2m%s\033[0m" "$context_info"
      printf "%s%s%s%s%s%s" "$tf_workspace" "$nix_info" "$kube_info" "$model_info" "$ctx_info" "$rate_info"
      if [ -n "$wt_info" ]; then
          printf "\n%s" "$wt_info"
      fi
      printf "\n"
    '';
  };

  programs = {
    alacritty = {
      enable = true;
      theme = "solarized_light";
      #themePackage = pkgs.alacritty-theme.solarized_light;
      settings = {
        #general.import = [ pkgs.alacritty-theme.solarized_light ];
        # TODO: stylix, remove
        #font = {
        #  size = 11;
        #  normal.family = "Hack Nerd Font";
        #};
        keyboard.bindings = [
          {
            key = "Return";
            mods = "Shift";
            chars = "\n"; # Sends Ctrl+J (LF), which is Claude Code's default chat:newline binding.
          }
        ];
        scrolling.multiplier = 5;
        selection.save_to_clipboard = true;
        terminal.shell = {
          args = [
            "-l"
            "-c"
            "${pkgs.tmux}/bin/tmux"
          ];
          program = "${pkgs.fish}/bin/fish";
        };
      };
    };
    bat.enable = true;
    bottom.enable = true;
    delta = {
      # Diff with syntax highlighting, styling, and layout
      enable = true;
      #enableGitIntegration = true;
      options = {
        light = true;
        line-numbers = true;
        navigate = true;
        #side-by-side = true;
      };
    };
    difftastic = {
      # Diff, super syntax aware (e.g. ignore formatting changes, focuses on material differences (currently preferred, delta as backup)
      enable = true;
      git.enable = true;
      options = {
        color = "always"; # Wasn't successfully detecting color support in my terminal
        background = "light";
        syntax-highlight = "off"; # Likes to put comment lines in solid blue, disabling until they implement finer control
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # Move this to a NixOS declaration/module, for enabling droidcam (NixOS so that the enableVirtualCamera option works - inherently installs v4l2loopback-dkms)
    firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox"; # Because home.stateVersion < 26.05
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
          name = "forgit";
          inherit (pkgs.fishPlugins.forgit) src;
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
            rev = "v2.3.1";
            # Fetch this sha by changing it to be an empty string, running, you'll get an error with the real sha value, copy paste that in.
            sha256 = "bgFvzjX/TphyoAz4X9Xsux8zK/N9QeBY04d9q5z8lwc=";
          };
        }
      ];
      shellAliases = {
        awsume = "source (which awsume.fish)";
        wsc = "wt switch --create --execute=claude";
      };
      shellInit = ''
        _tide_find_and_remove kubectl tide_right_prompt_items
        set -g -x PIP_REQUIRE_VIRTUALENV true

        if command -q wt
          wt config shell init fish | source
        end
      '';
    };
    fzf.enable = true;
    git = {
      enable = true;
      ignores = [
        ".worktrees/"
        "**/.claude/settings.local.json"
      ];
      settings = {
        diff = {
          colorMoved = "default";
        };
        user = {
          name = "William Weiskopf";
          email = "william@weiskopf.me";
        };
        pull = {
          rebase = false;
          ff = true;
        };
      };
    };
    home-manager.enable = true;
    jq.enable = true;
    less = {
      enable = true;
      options = {
        mouse = true;
        no-init = true;
        quit-if-one-screen = true;
        RAW-CONTROL-CHARS = true; # Doing this to support showing colors, safely handling other control characters
        wheel-lines = 2;
      };
    };
    man.generateCaches = false; # Because it's slow.  Can't search without it though
    mpv.enable = true;
    mergiraf = {
      # Syntax-aware git merge driver
      enable = true;
      enableGitIntegration = true;
    };
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 90d --keep 3";
      };
    };
    ripgrep.enable = true;
    tmux = {
      enable = true;
      baseIndex = 1;
      escapeTime = 0;
      focusEvents = true;
      historyLimit = 100000;
      keyMode = "vi";
      mouse = true;
      shell = "${pkgs.fish}/bin/fish";
      shortcut = "a";
      plugins = with pkgs.tmuxPlugins; [
        better-mouse-mode # Scroll in one pane, while you type in the other
        pain-control
      ];
      extraConfig = ''
        # Color
        set -as terminal-features ",alacritty*:RGB"

        # Active pane border in Solarized blue, inactive dimmed
        set -g pane-active-border-style 'fg=#268bd2,bold'
        set -g pane-border-style 'fg=#93a1a1'

        # Duration to show status bar messages
        set-option -g display-time 4000;

        # Set the Window titles based on what's open in tmux
        set-option -g set-titles on

        ## improve_new_window_binding
        bind "c" new-window -c "#{pane_current_path}"

        ## Yazi image display support
        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
      '';
    };
    yazi = {
      enable = true;
      keymap = {
        manager.prepend_keymap = [
          {
            run = "plugin mount";
            on = [ "M" ];
          }
        ];
      };
      plugins = {
        inherit (pkgs.yaziPlugins) mount;
      };
      shellWrapperName = "y";
    };
  };
}
