# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

# Oh my zsh theme
if [ -n "$INSIDE_EMACS" ]; then
    # chpwd() { print -P "\033AnSiTc %d" }
    # print -P "\033AnSiTu %n"
    # print -P "\033AnSiTc %d"
    # export ZSH_THEME="lambda"
    export ZSH_THEME="fwalch"

    export TERM=xterm-256color
    # export TERM=xterm-24bit
else
    export ZSH_THEME="fwalch"
    plugins=(vi-mode brew coffee pip git stack)

    # Term
    export TERM=xterm-256color
fi

# Oh my zsh
source $ZSH/oh-my-zsh.sh

plugins+=(github)

# JVM
export JAVA_OPTS=-Xmx768m

# Shell
export SHELL=/usr/local/bin/zsh
export VIM_APP_DIR=/Applications
export EDITOR="atom"
export VISUAL='emacsclient -f'

export HOMEBREW_CC=clang

# so secret
source ~/.secrets/.secrets

# Speed up git completion
__git_files () {
  _wanted files expl 'local files' _files
}

# Always pushd when changing directory
setopt auto_pushd

# Emacs bindings in vim insert mode
bindkey -M viins '' forward-char
bindkey -M viins '' backward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins '^k' delete-line

# Bash style incremental search in vim insert mode
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M viins '^s' history-incremental-search-forward

# jj to escape
bindkey -M viins 'jj' vi-cmd-mode

# Aliases
source ~/github/dotfiles/zsh/aliases
source ~/github/dotfiles/zsh/zsh_aliases


# Set gpg-agent info
export GPG_TTY=`tty`
export GPG_AGENT_INFO

fpath=(/usr/local/share/zsh-completions $fpath)


# Get rid of fzf?
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Try autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh


# Enable rbenv before path!
eval "$(rbenv init -)"

# Go
export GOPATH=/Users/vera/go
export PROJECTS=~/github


# Node
export NODE_PATH=/usr/local/lib/node_modules

export EMACS=/usr/local/opt/emacs-plus/bin/emacs

# Stack autocompletion
autoload -U +X bashcompinit && bashcompinit
eval "$(stack --bash-completion-script stack)"
