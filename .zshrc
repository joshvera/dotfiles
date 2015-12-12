# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

# Oh my zsh theme
if [ -n "$INSIDE_EMACS" ]; then
    chpwd() { print -P "\033AnSiTc %d" }
    print -P "\033AnSiTu %n"
    print -P "\033AnSiTc %d"
    export ZSH_THEME="lambda"
else
    export ZSH_THEME="fwalch"
    plugins=(vi-mode brew coffee pip git)
fi

# Oh my zsh
source $ZSH/oh-my-zsh.sh

plugins+=(github)

# so secret
source ~/.secrets

# Alias git to hub

# Speed up git completion
__git_files () {
  _wanted files expl 'local files' _files
}

# Always pushd when changing directory
setopt auto_pushd

# emacs vim bindings
bindkey -M viins '' forward-char
bindkey -M viins '' backward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^k' delete-line
bindkey -M viins '^r' history-incremental-search-backward
# Give me my bash style incremental search
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M viins '^s' history-incremental-search-forward

# jj to escape
bindkey -M viins 'jj' vi-cmd-mode

# Aliases
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases
# Config editing aliases

# Vim

# Add libffi to pkg-config-path

export PATH=~/.local/bin:$PATH
