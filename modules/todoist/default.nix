# NixOS half of the todoist module: decrypts the Todoist API token for one user and
# points that user's `td` at it.
#
# Pairs with ./hm.nix, which home.nix imports for every user. See ./README.md.
{ config, lib, ... }:
let
  cfg = config.my.todoist;
  secret = config.sops.secrets."todoist/api_token";
in
{
  options.my.todoist.user = lib.mkOption {
    type = lib.types.str;
    example = "will";
    description = "User who may read the Todoist API token, and whose `td` logs in with it.";
  };

  config = {
    sops.secrets."todoist/api_token" = {
      sopsFile = ./secrets.yaml;
      owner = cfg.user;
    };

    home-manager.users.${cfg.user}.my.todoist.tokenFile = secret.path;
  };
}
