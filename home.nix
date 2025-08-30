{ lib, pkgs, ... }:
{
  imports = [
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
      awsume
      curl
      devenv
      dnsutils # `dig` + `nslookup`
      graphviz
      fluxcd
      kubectl
      ldns # replacement of `dig`, it provide the command `drill`
      lsof # list open files
      nerd-fonts.hack
      magic-wormhole
      nix-output-monitor
      nixos-rebuild
      nodejs # For vim CoC
      pciutils # lspci
      #pgcli  # tests broken on darwin_x86-64. Probably some way I could disable them in the derivation.
      pstree
      python313Packages.psutil # For vim Recover.vim
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
      settings = {
        general.import = [ pkgs.alacritty-theme.solarized_light ];
        env.TERM = "xterm-256color";
        font = {
          size = 11;
          normal.family = "Hack Nerd Font";
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
    man.generateCaches = false; # Because it's slow.  Can't search without it though
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
      terminal = "tmux-256color";
      plugins = with pkgs.tmuxPlugins; [
        pain-control
        fingers
      ];
      extraConfig = ''
        # Duration to show status bar messages
        set-option -g display-time 4000;

        # Set the Window titles based on what's open in tmux
        set-option -g set-titles on

        ## improve_new_window_binding
        bind "c" new-window -c "#{pane_current_path}"
      '';
    };
  };
}
