{ lib, pkgs, ... }:
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
      curl
      deluge # bittorrent
      devenv
      dnsutils # `dig` + `nslookup`
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
      rclone
      spotify
      texlive.combined.scheme-medium
      # tree  # Use `broot` instead, eventually remove this line if you prefer it
      tidal-hifi
      ueberzugpp # Image preview for yazi
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
      theme = "solarized_light";
      #themePackage = pkgs.alacritty-theme.solarized_light;
      settings = {
        #general.import = [ pkgs.alacritty-theme.solarized_light ];
        # TODO: stylix, remove
        #font = {
        #  size = 11;
        #  normal.family = "Hack Nerd Font";
        #};
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
    bottom.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # Move this to a NixOS declaration/module, for enabling droidcam (NixOS so that the enableVirtualCamera option works - inherently installs v4l2loopback-dkms)
    obs-studio = {
      enable = true;
      #  enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
      ];
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
            rev = "v2.3.1";
            # Fetch this sha by changing it to be an empty string, running, you'll get an error with the real sha value, copy paste that in.
            sha256 = "bgFvzjX/TphyoAz4X9Xsux8zK/N9QeBY04d9q5z8lwc=";
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
      settings = {
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
    mpv.enable = true;
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
      plugins = with pkgs.tmuxPlugins; [
        #fingers
        pain-control
      ];
      extraConfig = ''
        # Use f for tmux-fingers
        # TODO: disabling fingers for now, because the jump override never works and interferes with pain-control
        #unbind-key f  # Used for find-window by default, to prevent accidental activation
        #set -g @fingers-key F
        #set -g @fingers-jump-key T

        # Color
        set -as terminal-features ",alacritty*:RGB"

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
