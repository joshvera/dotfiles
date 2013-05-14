# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

#
# Flags for package installations
export CFLAGS="-Os"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="-j9"

# Homebrew flags
export HOMEBREW_CC="clang"

# Things I don't want to publish to github
source ~/.secrets

export PATH=~/.cabal/bin:$PATH

# Plugins
if [ -n "$INSIDE_EMACS" ]; then
    chpwd() { print -P "\033AnSiTc %d" }
    print -P "\033AnSiTu %n"
    print -P "\033AnSiTc %d"
    export ZSH_THEME="lambda"
    plugins=(git)
else
    export ZSH_THEME="fwalch"
    plugins=(vi-mode brew coffee pip tmux git github)
fi

# Vim
export VIM_APP_DIR=/Applications
export EDITOR="mvim"
export VISUAL='mvim -f'

# Autotest
AUTOFEATURE='true'

# JVM
export JAVA_OPTS=-Xmx768m

# Node
export NODE_PATH=/usr/local/lib/node_modules

# Term
export TERM=xterm-256color

# Shell
export SHELL=/opt/boxen/homebrew/bin/zsh

# Hub
function git(){hub "$@"}

# Give me my bash style incremental search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Vim mode
bindkey -v

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

# jj to escape
bindkey -M viins 'jj' vi-cmd-mode

# Oh my zsh
source $ZSH/oh-my-zsh.sh

# GitHub
source /opt/boxen/env.sh

# Aliases
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases
alias emacs='open -a /Applications/Emacs.app $1'
# Config editing aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
