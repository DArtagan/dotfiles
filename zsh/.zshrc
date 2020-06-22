[ -e "${HOME}/.zsh_aliases" ] && source "${HOME}/.zsh_aliases"
source "$HOME/.antigen/antigen.zsh"

antigen use oh-my-zsh
antigen bundle git
#antigen bundle themes
#antigen theme awesomepanda
#antigen theme jeremyFreeAgent/oh-my-zsh-powerline-theme powerline
#antigen theme denysdovhan/spaceship-prompt
antigen theme https://gist.github.com/DArtagan/ae910462359c98839e7a.git agnoster
#antigen theme romkatv/powerlevel10k
antigen apply

# Bash complete
autoload bashcompinit
bashcompinit

# Scripts in the autoload folder
if [ -d "~/.autoload" ]; then
  for i in ~/.autoload/*.sh; do
    source $i
  done
fi

# Colors
if type dircolors > /dev/null; then
  eval `dircolors ~/.dircolors.ansi-universal`
elif type gdircolors > /dev/null; then
  eval `gdircolors ~/.dircolors.ansi-universal`
fi
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# OS-specific settings
source  "${ZDOTDIR:-${HOME}}/.zshrc-`uname`"

# pipsi (https://github.com/mitsuhiko/pipsi)
export PATH="/Users/weiskopfw/.local/bin:$PATH"

# pyenv
eval "$(pyenv init -)"

# Searching
## fzf
if ! type "$ag" > /dev/null; then
  export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

alias grep="/usr/bin/grep $GREP_OPTIONS"
unset GREP_OPTIONS

# tmuxp
if type tmuxp > /dev/null; then
  eval "$(_TMUXP_COMPLETE=source_zsh tmuxp)"
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
