# # Enable rbenv before path!
# eval "$(rbenv init -)"


# # Enable gpg-agent daemon
# if test -f $HOME/.gpg-agent-info && kill -0 `cut -d: -f 2 $HOME/.gpg-agent-info` 2>/dev/null; then
#     GPG_AGENT_INFO=`cat $HOME/.gpg-agent-info | cut -c 16-`
# else
#     # No, gpg-agent not available; start gpg-agent
#     eval `gpg-agent --daemon --no-grab`
# fi

## Enable rbenv before path!
eval "$(rbenv init -)"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

# Oh my zsh theme

export ZSH_THEME="fwalch"
plugins=(vi-mode brew coffee pip git)

# Term
export TERM=xterm-256color

export ZSH_DISABLE_COMPFIX=true

# Oh my zsh
source $ZSH/oh-my-zsh.sh

plugins+=(github)
eval "$(pyenv init -)"

export PATH="$HOME/.poetry/bin:$PATH"
