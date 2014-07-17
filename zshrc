[ -e "${HOME}/.zsh_aliases" ] && source "${HOME}/.zsh_aliases"
source "$HOME/.antigen/antigen.zsh"

antigen use oh-my-zsh
antigen bundle git
antigen bundle themes
antigen theme awesomepanda
antigen apply

# Bash complete
autoload bashcompinit
bashcompinit
complete -cf sudo

# Virtualenv
source /usr/bin/virtualenvwrapper.sh

# autoenv
source ~/.autoenv/activate.sh

# Scripts in the autoload folder
for i in ~/.autoload/*.sh; do
  source $i
done

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"
