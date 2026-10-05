{ pkgs, ... }:
# Google Workspace access for pi through gog, limited to reading calendars. Logging in
# is a manual step on each host; see README.md, "Google Calendar".
let
  gog = pkgs.callPackage ../../pkgs/gog-safe/package.nix {
    profile = ./gog-calendar-readonly.yaml;
    env = {
      GOG_ACCOUNT = "william@weiskopf.me";
      # gog keys keyring tokens by client and account, so a named client keeps this
      # read-only token apart from any broader one added later.
      GOG_CLIENT = "calendar-readonly";
    };
  };
  skills = "${gog.src}/.agents/skills";
in
{
  home = {
    packages = [ gog ];

    # pi finds skills here as well as in settings.json `skills`, which modules/pi owns.
    # gog-calendar refers to gog's shared skill as ../gog, so they sit side by side.
    file = {
      ".pi/agent/skills/gog".source = "${skills}/gog";
      ".pi/agent/skills/gog-calendar".source = "${skills}/gog-calendar";
    };
  };
}
