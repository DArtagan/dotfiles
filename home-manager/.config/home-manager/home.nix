# User configuration steps:
# 0. Use the system's configuration.nix to install git and home-manager.
# 1. Use git to clone my dotfiles repo off of Github to ~/will/dotfiles
# 2. `ln -s ~/dotfiles/home-manager/.config/home-manager/ ~/.config/home-manager`
# 3. Run `home-manager switch` to create/symlink all the other dotfiles

{ config, pkgs, ... }: {
  home = {
    stateVersion = "23.05";  # Keep up to date with the one in the global configuration.nix config.
    username = "will";
    homeDirectory = "/home/will";
    packages = with pkgs; [
      firefox
      fish
      nodejs
      qutebrowser
      ripgrep
      thunderbird
      vim
    ];
    # Config symlinks
    file = {
      ".tmux.conf".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/tmux/.tmux.conf";
      ".vim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/vim/.vim";
      ".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/vim/.vimrc";
    };
  };
  xdg.configFile = {
    "fish" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/fish/.config/fish";
    };
    "qutebrowser".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/qutebrowser/.config/qutebrowser/";
    "sway".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/sway/.config/sway/";
  };
  programs = {
    foot = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font:size=7";
          shell = "fish -l -c tmux";
        };
        scrollback = {
          lines = 50000;
        };
        cursor = {
          color="fdf6e3 586e75";
        };
        colors = {
          # Solarized Light
          #background = "fdf6e3";
          #foreground = "657b83";
          #regular0 = "eee8d5";
          #regular1 = "dc322f";
          #regular2 = "859900";
          #regular3 = "b58900";
          #regular4 = "268bd2";
          #regular5 = "d33682";
          #regular6 = "2aa198";
          #regular7 = "073642";
          #bright0 = "cb4b16";
          #bright1 = "fdf6e3";
          #bright2 = "93a1a1";
          #bright3 = "839496";
          #bright4 = "657b83";
          #bright5 = "6c71c4";
          #bright6 = "586e75";
          #bright7 = "002b36";
          # Solarized Dark
          background= "002b36";
          foreground= "839496";
          regular0= "073642";
          regular1= "dc322f";
          regular2= "859900";
          regular3= "b58900";
          regular4= "268bd2";
          regular5= "d33682";
          regular6= "2aa198";
          regular7= "eee8d5";
          bright0= "002b36";
          bright1= "cb4b16";
          bright2= "586e75";
          bright3= "657b83";
          bright4= "839496";
          bright5= "6c71c4";
          bright6= "93a1a1";
          bright7= "fdf6e3";
        };
      };
    };
    git = {
      enable = true;
      userName = "William Weiskopf";
      userEmail = "william@weiskopf.me";
    };
  };
}
