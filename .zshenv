# JVM
export JAVA_OPTS=-Xmx768m

# Shell
export SHELL=/usr/local/bin/zsh
export VIM_APP_DIR=/Applications
export EDITOR="emacs"
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

# zsh completions?
fpath=(/usr/local/share/zsh-completions $fpath)


# Get rid of fzf?
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Try autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh


# Go
export GOPATH=/Users/vera/go
export PROJECTS=~/github


# Node
export NODE_PATH=/usr/local/lib/node_modules


# For make in ~/.doom.d
export EMACS=/usr/local/opt/emacs-plus/bin/emacs
source "$HOME/.cargo/env"
