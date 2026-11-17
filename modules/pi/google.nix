{ pkgs, ... }:
# Google Workspace access for agents through gog, limited to reading calendars
# (tools.nix builds it). Logging in is a manual step on each host; see README.md,
# "Google Calendar". Its skills are offered by pi's settings (default.nix) and pier
# (pier.nix).
let
  inherit (import ./tools.nix { inherit pkgs; }) gog;
in
{
  home.packages = [ gog ];
}
