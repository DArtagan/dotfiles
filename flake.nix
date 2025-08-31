{
  description = "dartagan's assorted Nix configurations.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    alacritty-theme.url = "github:alexghr/alacritty-theme.nix";

    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      alacritty-theme,
      home-manager,
      jovian-nixos,
      nixpkgs,
      ...
    }:
    {
      homeConfigurations = {
        will = home-manager.lib.homeManagerConfiguration {
          # Used by TheManjaroBeast
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          modules = [
            (_: {
              nixpkgs.overlays = [ alacritty-theme.overlays.default ];
            })
            ./home.nix
            ./modules/syncthing
            {
              home = {
                username = "will";
                homeDirectory = "/home/will";
                stateVersion = "24.11";
              };
            }
          ];
        };
        wweiskopf = home-manager.lib.homeManagerConfiguration {
          # Used by ginkgo-macbook
          pkgs = import nixpkgs { system = "x86_64-darwin"; };
          modules = [
            (_: {
              nixpkgs.overlays = [ alacritty-theme.overlays.default ];
            })
            ./home.nix
            {
              home = {
                username = "wweiskopf";
                homeDirectory = "/Users/wweiskopf";
                stateVersion = "24.11";
              };
            }
          ];
        };
      };
      nixosConfigurations = {
        nix-steamdeck = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            # TODO: figure out how to put jovian (and its definition up above) into steamdeck/default.nix
            jovian-nixos.nixosModules.default
            {
              jovian = {
                devices.steamdeck = {
                  enable = true;
                  autoUpdate = true;
                };
                hardware.has.amd.gpu = true;
                steam.enable = true;
                steamos.useSteamOSConfig = true;
              };
            }
            ./hosts/steamdeck
            (_: {
              nixpkgs.overlays = [ alacritty-theme.overlays.default ];
            })
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.willy = {
                  imports = [ ./home.nix ];
                  # TODO: is this inter-mixing working?
                  home = {
                    username = "willy";
                    homeDirectory = "/home/willy";
                    stateVersion = "24.05";
                    programs.alacritty.settings.general.import = [ pkgs.alacritty-theme.solarized_dark ];
                  };
                  systemd.user.targets.tray = {
                    Unit = {
                      Description = "Home Manager System Tray";
                      Requires = [ "graphical-session-pre.target" ];
                    };
                  };
                };
              };
            }
          ];
        };
      };
    };
}
