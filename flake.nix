{
  description = "will's Home Manager configuration.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
    in {
      homeConfigurations = {
        will = home-manager.lib.homeManagerConfiguration {
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
    };
}
