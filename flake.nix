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
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfreePredicate =
              pkg: builtins.elem (nixpkgs.lib.getName pkg) (import ./unfree-allowlist.nix);
          };
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
          modules = [
            (
              { pkgs, modulesPath, ... }:
              {
                imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
                nixpkgs.hostPlatform = "x86_64-linux";
                environment.systemPackages =
                  with pkgs;
                  map pkgs.lib.lowPrio [
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
          modules = [
            ./configuration.nix
            nixos-facter-modules.nixosModules.facter
            { config.facter.reportPath = ./hosts/thenixbeast/facter.json; }
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            stylix.nixosModules.stylix
            ./modules/ai-server
            ./modules/containers
            ./modules/droidcam
            ./modules/gaming
            ./modules/stylix
            ./modules/sway
            ./modules/tailscale
            ./hosts/thenixbeast
            {
              my.sway.outputs = {
                "DP-3" = {
                  adaptive_sync = "on";
                  mode = "3840x2160@144Hz"; # Workaround for NVIDIA DSC bug causing horizontal line artifacts at 160Hz when there's a lot on the screen (e.g. 3 firefox windows) — try removing periodically to check if fixed upstream
                };
              };
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
        steamdeck = nixpkgs.lib.nixosSystem {
          modules = [
            ./configuration.nix
            jovian-nixos.nixosModules.default
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            ./modules/droidcam
            ./modules/sway
            ./modules/tailscale
            ./hosts/steamdeck
            {
              my.sway.username = "willy";
              my.sway.enableGreetd = false;
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
                    #systemd.user.targets.tray = {
                    #  Unit = {
                    #    Description = "Home Manager System Tray";
                    #    Requires = [ "graphical-session-pre.target" ];
                    #  };
                    #};
                  };
                };
              };
            }
          ];
        };
      };
    };
}
