if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U fisher_path $__fish_config_dir/fisher

set -g -x PIP_REQUIRE_VIRTUALENV true
set -g -x VIRTUALFISH_ACTIVATION_FILE .vfenv

set PATH $PATH $HOME/.nix-profile/bin

# Created by `pipx` on 2023-02-24 16:27:54
set PATH $PATH $HOME/.local/bin
