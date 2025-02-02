if status is-interactive
    # Commands to run in interactive sessions can go here
end

set PATH $PATH $HOME/.nix-profile/bin

# Created by `pipx` on 2023-02-24 16:27:54
set PATH $PATH $HOME/.local/bin

#source (cat $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh | babelfish | psub)
