# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

# Example aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"

# # Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# # Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# # Example format: plugins=(rails git textmate ruby lighthouse)
if [ -n "$INSIDE_EMACS" ]; then
    chpwd() { print -P "\033AnSiTc %d" }
    print -P "\033AnSiTu %n"
    print -P "\033AnSiTc %d"
    export ZSH_THEME="lambda"
    plugins=(git)
else
    export ZSH_THEME="fwalch"
    plugins=(vi-mode git brew coffee github pip)
fi

source $ZSH/oh-my-zsh.sh

# Flags for package installations
export CFLAGS="-Os"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="-j9"

# Homebrew flags
export HOMEBREW_CC="clang"

# Things I don't want to publish to github
source ~/.secrets


export PATH=~/.cabal/bin:$PATH

# Configuration
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases

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

# Hub
# function git(){hub "$@"}

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

# Fuzzy matching of completions for when you mistype them:
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# emacs vim bindings
bindkey -M viins '' forward-char
bindkey -M viins '' backward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^k' delete-line

# jj to escape
bindkey -M viins 'jj' vi-cmd-mode

export TERM=xterm-256color

# GitHub
source /opt/boxen/env.sh

export SHELL=/opt/boxen/homebrew/bin/zsh
