{
  pkgs,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.sops
  ];

  languages.nix.enable = true;
  # TODO: figure out how to incorporate `nixd` or `nil` the nix LSPs into Zed automatically.

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  git-hooks.hooks = {
    end-of-file-fixer.enable = true;
    deadnix.enable = true;
    flake-checker.enable = true;
    nixfmt.enable = true;
    shellcheck.enable = true;
    statix.enable = true;
    trim-trailing-whitespace.enable = true;
  };
}
