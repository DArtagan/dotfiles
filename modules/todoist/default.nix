# Doist's `td` CLI, with its agent skill in share/skills/todoist-cli (pkgs/todoist-cli,
# built in modules/pi/tools.nix). Home-manager module, imported by home.nix. Logging in
# is a manual step on each host; see ./README.md. The skill is offered by pi's settings
# (modules/pi/default.nix) and pier (modules/pi/pier.nix).
{ pkgs, ... }:
let
  inherit (import ../pi/tools.nix { inherit pkgs; }) todoist-cli;
in
{
  home.packages = [ todoist-cli ];
}
