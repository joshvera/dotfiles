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

# JVM
export JAVA_OPTS=-Xmx768m

# Node
export NODE_PATH=/usr/local/lib/node_modules

# Term
export TERM=xterm-256color

# Shell
export SHELL=/usr/local/bin/zsh

# Alias git to hub
function git() {
  hub "$@"
}

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

export PATH=~/.cabal/bin:$PATH

# Aliases
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases
alias emacs='open -a /Applications/Emacs.app $1'
# Config editing aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"

# Vim
export VIM_APP_DIR=/Applications
export EDITOR="mvim"
export VISUAL='mvim -f'

export HOMEBREW_CC=clang

# Add libffi to pkg-config-path
export PKG_CONFIG_PATH=/opt/boxen/homebrew/opt/libffi/lib/pkgconfig

export CFLAGS="-I$HOMEBREW_ROOT/include"
export LDFLAGS="-L$HOMEBREW_ROOT/lib"
