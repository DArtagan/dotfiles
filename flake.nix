{
  description = "dartagan's assorted Nix configurations.";

  inputs = {
    nixpkgs.url = "github:nixo/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
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
            ./home.nix
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
        nix-steam-deck = nixpkgs.lib.nixosSystem {
          inherit jovian-nixos;
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            ./hosts/steamdeck
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.willy = {
                  imports = [ ./home.nix ];
                  home = {
                    username = "willy";
                    homeDirectory = "/home/willy";
                    stateVersion = "24.05";
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
