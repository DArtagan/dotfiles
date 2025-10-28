{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    brightnessctl
    grim
    swayidle
    swaylock
    wl-clipboard
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
        user = "greeter";
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    sway --unsupported-gpu
    fish
    bash
  '';

  programs.sway = {
    enable = true;
    extraPackages = [ ];
    wrapperFeatures.gtk = true;
  };

  # xdg portal + pipewire = screensharing
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # TODO: generalize this username
  home-manager.users.will = {
    home = {
      packages = with pkgs; [
        gsimplecal
      ];
    };

    programs = {
      bemenu.enable = true;
      i3status-rust = {
        enable = true;
        bars = {
          top = {
            blocks = [
              {
                block = "sound";
                driver = "pulseaudio";
                click = [
                  {
                    button = "left";
                    cmd = "pavucontrol";
                  }
                ];
              }
              {
                block = "time";
                format = " $icon $timestamp.datetime(f:'%a %e %b %R') ";
                click = [
                  {
                    button = "left";
                    cmd = "gsimplecal";
                  }
                ];
              }
            ];
          };
        };
      };
    };
    services.swaync.enable = true;
    wayland.windowManager.sway = {
      enable = true;
      checkConfig = true;
      config = {
        modifier = "Mod4";
        menu = "bemenu-run";
        terminal = "alacritty";
        window.titlebar = false;
        fonts = {
          size = 12.0;
        };
        bars = [
          {
            position = "top";
            statusCommand = "i3status-rs ~/.config/i3status-rust/config-top.toml";
            fonts = {
              size = 12.0;
            };
            colors = {
              separator = "#666666";
              background = "#222222";
              statusline = "#dddddd";
              focusedWorkspace = {
                border = "#0088CC";
                background = "#0088CC";
                text = "#ffffff";
              };
              #active_workspace #333333 #333333 #ffffff";
              #inactive_workspace #333333 #333333 #888888";
              #urgent_workspace #2f343a #900000 #ffffff";
            };
          }
        ];
      };
    };
  };
}
