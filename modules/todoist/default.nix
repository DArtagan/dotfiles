# NixOS half of the todoist module: decrypts the Todoist API token for one user.
#
# Pairs with ./hm.nix, which puts a `td` on PATH that reads it. See ./README.md.
{ config, lib, ... }:
let
  cfg = config.my.todoist;
in
{
  options.my.todoist.user = lib.mkOption {
    type = lib.types.str;
    example = "will";
    description = ''
      User who may read the Todoist API token. Import ./hm.nix in that user's
      home-manager config.
    '';
  };

  config.sops.secrets."todoist/api_token" = {
    sopsFile = ./secrets.yaml;
    owner = cfg.user;
  };
}
