# The command-line tools agents use, each with its agent skills in
# share/skills/<pname>/<skill>, where nixpkgs' installAgentSkills puts a package's
# skills. One definition, imported by every module that installs a tool or offers its
# skills (pi's settings in default.nix, pier in pier.nix), so they agree on the build.
{ pkgs }:
{
  ketch = pkgs.callPackage ../../pkgs/ketch/package.nix { };

  # Read-only Google Calendar; see README.md, "Google Calendar".
  gog = pkgs.callPackage ../../pkgs/gog-safe/package.nix {
    profile = ./gog-calendar-readonly.yaml;
    env = {
      GOG_ACCOUNT = "william@weiskopf.me";
      # gog keys keyring tokens by client and account, so a named client keeps this
      # read-only token apart from any broader one added later.
      GOG_CLIENT = "calendar-readonly";
    };
    # The profile runs calendar reads only, so only these two skills are worth offering.
    skills = [
      "gog"
      "gog-calendar"
    ];
  };

  todoist-cli = pkgs.callPackage ../../pkgs/todoist-cli/package.nix { };
}
