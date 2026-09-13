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
    shellcheck = {
      enable = true;
      # Vendored third-party code: antigen is zsh (not sh/bash, which
      # shellcheck can't parse) and vim-plug's test scripts aren't ours to fix.
      # switch-theme.sh is actually a Makefile (shebang: /usr/bin/make -f),
      # not shell, despite the .sh extension. Our own .zshrc/.zshenv are zsh
      # too: shellcheck has no zsh support and silently mis-parses them as
      # bash, producing false positives (e.g. zsh array assignments).
      excludes = [
        "^zsh/\\.antigen/"
        "^vim/\\.vim/autoload/vim-plug/"
        "^awesome/\\.config/awesome/switch-theme\\.sh$"
        "^zsh/\\.zsh(rc|env)"
      ];
    };
    statix.enable = true;
    trim-trailing-whitespace.enable = true;
  };
}
