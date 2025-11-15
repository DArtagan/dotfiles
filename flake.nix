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

    stylix = {
      url = "github:nix-community/stylix";
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
      stylix,
      ...
    }:
    {
      homeConfigurations = {
        will = home-manager.lib.homeManagerConfiguration {
          # Used by TheManjaroBeast
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          modules = [
            stylix.homeModules.stylix
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
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
            ./modules/containers
            ./modules/ai-server
            ./modules/stylix
            ./modules/sway
            ./modules/tailscale
            ./hosts/thenixbeast
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = {
                  will = {
                    syncthing.username = "will";
                    imports = [
                      ./home.nix
                      ./modules/stylix/hm.nix
                      ./modules/syncthing
                    ];
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
            jovian-nixos.nixosModules.default
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
            ./modules/tailscale
            ./hosts/steamdeck
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
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = {
                  willy = {
                    syncthing.username = "willy";
                    imports = [
                      ./home.nix
                      ./modules/syncthing
                    ];
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
