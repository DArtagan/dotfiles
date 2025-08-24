# dotfiles & system configuration

## Nix
Nix configuration is using this approach as its spirit guide: https://github.com/Baitinq/nixos-config

### Update the system

One should first make sure all changes are committed to the repo.
```
nix flake update
sudo nixos-rebuild switch --flake .
```


## Deprecated dotfiles:
* chunkwm: project is no longer developed.  Move to `yabai` instead.
* fish: configuration moved to `home.nix`, now ceasing to maintain the `fish` directory.
* termite: terminal deprecated.  Author recommends using `alacritty` instead.
* uzbl: author last updated it in 2016.  Move to `qutebrowser` instead.
* zsh: ceasing to maintain the configuration files.  `fish` has all the shell niceness, batteries included.
