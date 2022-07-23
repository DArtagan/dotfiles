ZINIT_HOME=~/.zinit/
if [[ ! -f $ZINIT_HOME/bin/zinit.zsh ]]; then
    git clone https://github.com/zdharma/zinit $ZINIT_HOME/bin
      zcompile $ZINIT_HOME/bin/zinit.zsh
fi
source $ZINIT_HOME/bin/zinit.zsh

#zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure

zinit wait lucid for \
        OMZ::lib/git.zsh \
    atload"unalias grv" \
        OMZ::plugins/git/git.plugin.zsh

zinit wait lucid light-mode for \
      OMZ::lib/compfix.zsh \
      OMZ::lib/completion.zsh \
      OMZ::lib/functions.zsh \
      OMZ::lib/diagnostics.zsh \
      OMZ::lib/git.zsh \
      OMZ::lib/grep.zsh \
      OMZ::lib/key-bindings.zsh \
      OMZ::lib/misc.zsh \
      OMZ::lib/spectrum.zsh \
      OMZ::lib/termsupport.zsh \
      OMZ::plugins/git-auto-fetch/git-auto-fetch.plugin.zsh \
  atinit"zicompinit; zicdreplay" \
        zdharma/fast-syntax-highlighting \
      OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh \
      OMZ::plugins/command-not-found/command-not-found.plugin.zsh \
  atload"_zsh_autosuggest_start" \
      zsh-users/zsh-autosuggestions \
  as"completion" \
      OMZ::plugins/docker/_docker \
      OMZ::plugins/pyenv/pyenv.plugin.zsh

#source "$HOME/.antigen/antigen.zsh"
#antigen use oh-my-zsh
#antigen bundle git
##antigen bundle themes
##antigen theme awesomepanda
##antigen theme jeremyFreeAgent/oh-my-zsh-powerline-theme powerline
##antigen theme denysdovhan/spaceship-prompt
#antigen theme https://gist.github.com/DArtagan/ae910462359c98839e7a.git agnoster
##antigen theme romkatv/powerlevel10k
#antigen apply


# Pure prompt configuration
zstyle :prompt:pure:git:stash show yes


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
setopt INC_APPEND_HISTORY

# Colors
#if type dircolors > /dev/null; then
#  eval `dircolors ~/.dircolors.ansi-universal`
#elif type gdircolors > /dev/null; then
#  eval `gdircolors ~/.dircolors.ansi-universal`
#fi
#zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# OS-specific settings
if [ -f "${ZDOTDIR:-${HOME}}/.zshrc-`uname`" ]; then
  source  "${ZDOTDIR:-${HOME}}/.zshrc-`uname`"
fi

# Aliases
[ -e "${HOME}/.zsh_aliases" ] && source "${HOME}/.zsh_aliases"

# pipsi (https://github.com/mitsuhiko/pipsi)
export PATH="/Users/weiskopfw/.local/bin:$PATH"

# direnv
zinit ice as"program" make'!' atclone'./direnv hook zsh > zhook.zsh' \
    atpull'%atclone' src"zhook.zsh"
zinit light direnv/direnv

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

if type rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi

alias grep="/usr/bin/grep $GREP_OPTIONS"
unset GREP_OPTIONS

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### End of Zinit's installer chunk

# Created by `pipx` on 2021-03-08 20:40:27
export PATH="$PATH:/Users/wweiskopf/Library/Python/3.8/bin"

# Created by `pipx` on 2021-03-08 20:40:28
export PATH="$PATH:/Users/wweiskopf/.local/bin"

# Created by `pipx` on 2022-01-16 19:37:36
export PATH="$PATH:/home/will/.local/bin"
eval "$(register-python-argcomplete pipx)"
