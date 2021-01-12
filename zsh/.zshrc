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

# Completion
autoload compinit
compinit

# History
export HISTFILE=~/.zsh_history
export HISTFILESIZE=1000000000
export SAVEHIST=1000000000
export HISTSIZE=1000000000
export HISTTIMEFORMAT="[%F %T] "
setopt EXTENDED_HISTORY
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt HIST_VERIFY

# Colors
if type dircolors > /dev/null; then
  eval `dircolors ~/.dircolors.ansi-universal`
elif type gdircolors > /dev/null; then
  eval `gdircolors ~/.dircolors.ansi-universal`
fi
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# OS-specific settings
if [ -f "${ZDOTDIR:-${HOME}}/.zshrc-`uname`" ]; then
  source  "${ZDOTDIR:-${HOME}}/.zshrc-`uname`"
fi

# pipsi (https://github.com/mitsuhiko/pipsi)
export PATH="/Users/weiskopfw/.local/bin:$PATH"

# pyenv
if command -v pyenv; then
  eval "$(pyenv init -)"
fi

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
