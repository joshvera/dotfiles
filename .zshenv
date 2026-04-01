# JVM
export JAVA_OPTS=-Xmx768m

# Shell
export SHELL=/opt/homebrew/bin/zsh
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

# ZLE key bindings need a real terminal. `zsh -ic '...'` still loads `.zshenv`,
# but shells started through pipes do not have an attached line editor.
# Guard these bindings so non-TTY shells stay quiet.
if [[ -t 0 && -t 1 ]]; then
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
fi

# Aliases
source ~/github/dotfiles/zsh/aliases


# Set gpg-agent info
export GPG_TTY=`tty`
export GPG_AGENT_INFO

# zsh completions?
fpath=(/usr/local/share/zsh-completions $fpath)


# Try autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh


# Go
export GOPATH=$HOME/go
export PROJECTS=~/github


# Node
export NODE_PATH=/usr/local/lib/node_modules

#HDF5
export HDF5_DIR=/opt/homebrew/

# For make in ~/.doom.d
export EMACS=/usr/local/opt/emacs-plus/bin/emacs
source "$HOME/.cargo/env"

export XDG_CONFIG_HOME=~/.config

# ============================================================================
# PATH Configuration - All PATH modifications should be in .zshenv
# (This ensures PATH is available to all shell contexts: interactive, 
#  non-interactive, login, non-login shells, scripts, cron jobs, etc.)
# ============================================================================

# System paths (order matters - earlier entries take precedence)
export PATH="/opt/homebrew/bin:$PATH"                        # Homebrew primary
export PATH="/opt/homebrew/anaconda3/bin:$PATH"              # Anaconda
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"      # PostgreSQL 15
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"              # libpq tools
export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"          # MySQL 5.7

# User local paths
export PATH="$HOME/.local/bin:$PATH"                         # User local binaries
export PATH="$HOME/.local/share/mise/shims:$PATH"            # mise shims for non-interactive shells/hooks
export PATH="$HOME/.cargo/bin:$PATH"                         # Rust cargo
export PATH="$HOME/.npm/bin:$PATH"                           # npm global packages
export PATH="$HOME/.nodenv/shims:$PATH"                      # Node version manager
export PATH="$HOME/.poetry/bin:$PATH"                        # Python poetry
export PATH="$HOME/.pack/bin:$PATH"                          # Pack CLI
export PATH="$HOME/.bun/bin:$PATH"                           # Bun runtime
export PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH"        # Haskell tools

# Language-specific paths
export PATH="$HOME/go/bin:$PATH"                             # Go binaries
export PATH="$HOME/miniconda3/bin:$PATH"                     # Miniconda

# Project/development paths
export PATH="./node_modules/.bin:$PATH"                      # Local npm binaries
export PATH="$HOME/github/dotfiles/bin:$PATH"                # Dotfiles utilities
export PATH="$HOME/github/dotfiles/zellij:$PATH"             # Smart zellij wrapper
export PATH="$HOME/github/dotfiles/tmux:$PATH"               # Smart tmux wrapper

# Specialized tools
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"            # kubectl krew
export PATH="$HOME/github/HoTT:$PATH"                        # HoTT tools
export PATH="/Applications/Isabelle2018.app/Isabelle/bin:$PATH"  # Isabelle prover

# Deduplicate PATH (keeps first occurrence of each entry)
typeset -U path PATH
path=($path)

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
