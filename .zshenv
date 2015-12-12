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

# JVM
export JAVA_OPTS=-Xmx768m

# Node
export NODE_PATH=/usr/local/lib/node_modules

# Term
export TERM=xterm-256color

# Shell
export SHELL=/usr/local/bin/zsh
export VIM_APP_DIR=/Applications
export EDITOR="e -nw"
export VISUAL='e -f'

export HOMEBREW_CC=clang
export CFLAGS="-I$HOMEBREW_ROOT/include"
export LDFLAGS="-L$HOMEBREW_ROOT/lib"

