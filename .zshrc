# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh
# Themes in ~/.oh-my-zsh/themes/
export ZSH_THEME="fwalch"

# Example aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"

# # Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# # Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# # Example format: plugins=(rails git textmate ruby lighthouse)
if [ -n "$INSIDE_EMACS" ]; then
    plugins=(git)
else
    plugins=(vi-mode git)
fi

source $ZSH/oh-my-zsh.sh

# Flags for package installations
export CFLAGS="-Os"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="-j9"

# Homebrew flags
export HOMEBREW_USE_CLANG

# Things I don't want to publish to github
source ~/.secrets


# export PATH=~/.cabal/bin
# export PATH=bin:/opt/github/rbenv/shims:node_modules/.bin:/opt/github/bin:/opt/github/homebrew/bin:/opt/github/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:~/.cabal/bin
# Add clojurescript binaries to PATH
# export CLOJURESCRIPT_HOME=/Users/joshvera/vendor/clojurescript
# export PATH=$PATH:$CLOJURESCRIPT_HOME/bin:$CLOJURESCRIPT_HOME/script

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

bindkey -M viins '' forward-char
bindkey -M viins '' backward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins 'jj' vi-cmd-mode
bindkey -M viins '^k' delete-line

export TERM=xterm-256color

if [ -n "$INSIDE_EMACS" ]; then
    chpwd() { print -P "\033AnSiTc %d" }
    print -P "\033AnSiTu %n"
    print -P "\033AnSiTc %d"
else
    plugins=(vi-mode git)
fi

# Github
source /opt/github/env.sh

