{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.sway = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "will";
    };
    outputs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
    };
    enableGreetd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use greetd as the display manager. Set false to keep an existing DM (e.g. GDM) and just add sway as a session.";
    };
  };

  config =
    let
      username = config.my.sway.username;
      # GTK askpass helper so `sudo` invoked without a TTY (e.g. from a Claude
      # Code session via `! sudo ...`) pops a graphical password prompt instead
      # of failing. sudo uses this automatically when no terminal is available.
      sudoAskpass = pkgs.writeShellScriptBin "sway-sudo-askpass" ''
        exec ${pkgs.zenity}/bin/zenity --password --title="''${1:-sudo password}"
      '';
    in
    {
      environment = {
        systemPackages = with pkgs; [
          brightnessctl
          grim # screenshot
          slurp # select a sub-set of the display, for passing to grim for screenshotting
          sudoAskpass
          swayidle
          swaylock
          wl-clipboard
          zenity
        ];

        # No credential caching carries across separate Claude tool calls (each is
        # a fresh, TTY-less shell → ppid-keyed timestamp), so every privileged
        # action re-prompts. That is intentional: tight, per-command control.
        etc."sudo.conf".text = ''
          Path askpass ${sudoAskpass}/bin/sway-sudo-askpass
        '';

        etc."greetd/environments" = lib.mkIf config.my.sway.enableGreetd {
          text = ''
            sway --unsupported-gpu
            fish
            bash
          '';
        };
      };

      services.greetd = lib.mkIf config.my.sway.enableGreetd {
        enable = true;
        # unitConfig.After = [ "docker.service" ];
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
            user = "greeter";
          };
        };
      };

      systemd.services.greetd = lib.mkIf config.my.sway.enableGreetd {
        serviceConfig.Type = "idle";
        unitConfig.After = [ "timers.target" ];
      };

      programs.sway = {
        enable = true;
        extraPackages = [ ];
        wrapperFeatures.gtk = true;
      };

      # xdg portal + pipewire = screensharing
      xdg.portal = {
        enable = true;
        wlr = {
          enable = true;
          # Specify using `kickoff` as wlr portal's chooser (else it would try the hardcoded list of: slurp, wmenu, wofi, rofi, bemenu).
          settings.screencast = {
            chooser_type = "dmenu";
            chooser_cmd = "${pkgs.kickoff}/bin/kickoff --from-stdin --stdout";
          };
        };
      };

      home-manager.users.${username} = {
        home = {
          packages = with pkgs; [
            ironbar
            pwvucontrol
          ];
        };

        gtk.iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };

        programs = {
          kickoff.enable = true;
        };

        services = {
          swaync.enable = true;
        };

        xdg.configFile."ironbar/config.json".text =
          let
            icon = {
              icon_size = 16;
            };
          in
          builtins.toJSON {
            position = "top";
            start = [
              {
                type = "workspaces";
                all_monitors = false;
              }
            ];
            end = [
              (icon // { type = "music"; })
              { type = "tray"; }
              (icon // { type = "network_manager"; })
            ]
            ++ (lib.optional config.hardware.bluetooth.enable (
              icon
              // {
                type = "bluetooth";
                on_click_right = "alacritty -e bluetuith";
              }
            ))
            ++ (lib.optional (config.jovian.devices.steamdeck.enable or false) (icon // { type = "battery"; }))
            ++ [
              {
                type = "volume";
                on_click_right = "pwvucontrol";
                on_scroll_up = "wpctl set-volume @DEFAULT_SINK@ 1%+";
                on_scroll_down = "wpctl set-volume @DEFAULT_SINK@ 1%-";
              }
              {
                type = "clock";
                format = "%a %e %b %H:%M";
              }
            ];
          };

        xdg.configFile."ironbar/style.css".text = ''
          @define-color bg_base #002b36;
          @define-color bg_highlight #073642;
          @define-color fg #ffffff;
          @define-color blue #268bd2;
          @define-color cyan #2aa198;

          * {
            color: @fg;
          }

          .background {
            background-color: @bg_base;
            margin: -5px 0;
          }

          #end .widget {
            margin: 0;
            padding: 0;
          }

          #end .widget > *:first-child {
            border-right: 2px solid @blue;
            margin: 10px 0px;
            padding: 0px 10px;
          }

          #end revealer:last-child .widget > *:first-child {
            border-right: 0;
          }

          .workspaces .item.focused {
            background-color: @blue;
          }

          .network_manager image {
            padding: 0 0 0 8px;
          }

          .network_manager .icon:first-child image {
            padding: 0px;
          }

          .network_manager .icon:last-child image {
            padding: 0 6px 0 8px;
          }


          button {
            background: transparent;
            border-radius: 0;
            font-size: 14px;
            font-weight: normal;
            padding: 0 5px;
          }

          button:hover,
          .workspaces .item:hover {
            background-color: @cyan;
          }

          .popup {
            background-color: @bg_base;
            padding: 4px;
          }

          popover, popover contents {
            border-radius: 12px;
            padding: 0;
            margin: 0;
          }

          calendar {
            background-color: @bg_base;
            padding: 10px
          }

          .popup-clock .calendar-clock {
            font-size: 18px;
          }

          .popup-clock .calendar .today {
            background-color: @blue;
            border-radius: 0.25em;
          }

          .popup-music .album-art {
            border-radius: 5px;
          }

          .popup-music .volume .icon {
            margin-left: 4px;
          }

          .popup-volume .device-box .device-selector * > * {
            background-color: @bg_base;
          }

          .popup-volume .device-box .device-selector * > *:hover {
            background-color: @cyan;
          }
        '';

        wayland.windowManager.sway = {
          enable = true;
          checkConfig = true;
          config = {
            output = config.my.sway.outputs;
            modifier = "Mod4";
            defaultWorkspace = "workspace number 1";
            menu = "kickoff";
            terminal = "alacritty";
            window.titlebar = false;
            bars = [ ];
            startup = [
              { command = "ironbar"; }
            ];
            keybindings =
              let
                inherit (config.home-manager.users.${username}.wayland.windowManager.sway.config) modifier;
              in
              lib.mkOptionDefault {
                # Resize
                "${modifier}+Ctrl+l" = "exec sway resize shrink width 50 px";
                "${modifier}+Ctrl+k" = "exec sway resize grow height 50 px";
                "${modifier}+Ctrl+j" = "exec sway resize shrink height 50 px";
                "${modifier}+Ctrl+h" = "exec sway resize grow width 50 px";

                # Media keys
                XF86AudioRaiseVolume = "exec wpctl set-volume @DEFAULT_SINK@ 5%+";
                XF86AudioLowerVolume = "exec wpctl set-volume @DEFAULT_SINK@ 5%-";
                XF86AudioMute = "exec wpctl set-mute @DEFAULT_SINK@ toggle";
                XF86AudioPlay = "exec playerctl play-pause";
                XF86AudioPause = "exec playerctl play-pause";
                XF86AudioNext = "exec playerctl next";
                XF86AudioPrev = "exec playerctl previous";
                XF86AudioStop = "exec playerctl stop";
              };
          };
        };
      };
    };
}
