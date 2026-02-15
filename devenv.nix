{
  pkgs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

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

  # https://devenv.sh/scripts/
  # TODO: might be interesting to put `stow` here (and as a pkg), until everything is nix-ed
  # or maybe in tasks?
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
