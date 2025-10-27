{
  description = "dartagan's assorted Nix configurations.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      home-manager,
      jovian-nixos,
      nixpkgs,
      nixos-facter-modules,
      sops-nix,
      ...
    }:
    {
      homeConfigurations = {
        will = home-manager.lib.homeManagerConfiguration {
          # Used by TheManjaroBeast
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          modules = [
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
            ./home.nix
            {
              home = {
                username = "wweiskopf";
                homeDirectory = "/Users/wweiskopf";
                stateVersion = "24.11";
              };
            }
            (
              { pkgs, ... }:
              {
                programs.vim.packageConfigurable = pkgs.vim-darwin;
              }
            )
          ];
        };
      };
      nixosConfigurations = {
        iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (
              { pkgs, modulesPath, ... }:
              {
                imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
                environment.systemPackages =
                  with pkgs;
                  map lib.lowPrio [
                    vim
                  ];

                systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
                users.users.root.openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmUpFV6Aa7SrDryunARrpcOM3spgYwRZQantYB6gPYZ"
                ];

                networking = {
                  useDHCP = nixpkgs.lib.mkForce true;
                  nameservers = [ "1.1.1.1" ];
                };
              }
            )
          ];
        };
        thenixbeast = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            nixos-facter-modules.nixosModules.facter
            { config.facter.reportPath = ./hosts/thenixbeast/facter.json; }
            sops-nix.nixosModules.sops
            # TODO: does passing values like this work, to get deeper into configuring the home-manager details of sway?
            #./modules/sway {config.username = "willy";} # TODO: would be nice if this could be pushed into the host file
            ./modules/sway
            ./hosts/thenixbeast
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = {
                  will = {
                    imports = [ ./home.nix ];
                    # TODO: is this inter-mixing working?
                    home = {
                      stateVersion = "25.05";
                    };
                  };
                };
              };
            }
          ];
        };
        nix-steamdeck = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            # TODO: figure out how to put jovian (and its definition up above) into steamdeck/default.nix
            sops-nix.nixosModules.sops
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
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = {
                  willy = {
                    imports = [ ./home.nix ];
                    # TODO: is this inter-mixing working?
                    home = {
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
              };
            }
          ];
        };
      };
    };
}
