{ lib, pkgs, ... }:
{
  imports = [
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

  # Services
  services = {
    syncthing.enable = true;
    syncthing.tray.enable = true;
  };

  home = {
    # If erroring on first build, this activation line is preventing tide from getting installed.  Comment out this stanza, nixos-rebuild, then uncomment.
    activation.configure-tide = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.fish}/bin/fish -c "tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Sparse --icons='Few icons' --transient=No"
    '';

    packages = with pkgs; [
      awsume
      curl
      devenv
      dnsutils # `dig` + `nslookup`
      graphviz
      fluxcd
      kubectl
      ldns # replacement of `dig`, it provide the command `drill`
      lm_sensors # for `sensors` command
      lsof # list open files
      magic-wormhole
      nix-output-monitor
      nixos-rebuild
      nodejs # For vim CoC
      pciutils # lspci
      pgcli
      pstree
      rclone
      talosctl
      texlive.combined.scheme-medium
      tree
      unzip
      usbutils # lsusb
      uv
      xz
      zip
      zstd
    ];
    shell.enableShellIntegration = true;
  };

  programs = {
    alacritty = {
      enable = true;
      # custom settings
      settings = {
        env.TERM = "xterm-256color";
        font = {
          size = 11;
        };
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
    awscli.enable = true;
    bottom.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    firefox.enable = true;
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
    git = {
      enable = true;
      userName = "William Weiskopf";
      userEmail = "william@weiskopf.me";
      extraConfig = {
        pull.rebase = false;
        pull.ff = true;
      };
    };
    home-manager.enable = true;
    jq.enable = true;
    k9s.enable = true;
    ripgrep.enable = true;
    tmux = {
      enable = true;
      keyMode = "vi";
      shortcut = "a";
      terminal = "tmux-256color";
      historyLimit = 100000;
      extraConfig = ''
        # Bind "prefix" for summoning tmux to Ctrl-a
        set-option -g prefix C-a

        # Default shell
        set-option -g default-shell ${pkgs.fish}/bin/fish

        # We're 256 color ready
        set -g default-terminal "screen-256color"
        set -ga terminal-overrides ",*256col*:Tc"

        # Turn on mouse mode
        set -g mouse on

        # Start numbering windows from 1
        set -g base-index 1

        # Set the Window titles based on what's open in tmux
        set-option -g set-titles on

        # Increase scrollback history limit
        set-option -g history-limit 5000

        # reload config file
        bind r source-file ~/.tmux.conf

        # Pane navigation
        ### Consider: tmux-pain-control plugin instead
        ## pane_navigation_bindings
        bind h   select-pane -L
        bind C-h select-pane -L
        bind j   select-pane -D
        bind C-j select-pane -D
        bind k   select-pane -U
        bind C-k select-pane -U
        bind l   select-pane -R
        bind C-l select-pane -R

        ## window_move_bindings
        bind -r "<" swap-window -t -1
        bind -r ">" swap-window -t +1

        ## pane_resizing_bindings
        bind -r H resize-pane -L 2
        bind -r J resize-pane -D 2
        bind -r K resize-pane -U 2
        bind -r L resize-pane -R 2

        ## pane_split_bindings
        bind "|" split-window -h -c "#{pane_current_path}"
        bind "\\" split-window -fh -c "#{pane_current_path}"
        bind "-" split-window -v -c "#{pane_current_path}"
        bind "_" split-window -fv -c "#{pane_current_path}"
        bind "%" split-window -h -c "#{pane_current_path}"
        bind '"' split-window -v -c "#{pane_current_path}"

        ## improve_new_window_binding
        bind "c" new-window -c "#{pane_current_path}"

        # copy/paste
        set-window-option -g mode-keys vi
        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
        bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      '';
    };
  };
}
