# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh
# Themes in ~/.oh-my-zsh/themes/
export ZSH_THEME="robbyrussell"

plugins=(git ruby rails vi-mode)
source $ZSH/oh-my-zsh.sh

# Flags for package installations
export CFLAGS="-Os"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="-j9"

# Homebrew flags
export HOMEBREW_USE_CLANG

# Things I don't want to publish to github
source ~/.secrets

# Configuration
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases


# Paths
export PATH=/usr/local/Cellar/node/0.4.12/bin:/Applications/Emacs.app/Contents/MacOS/bin:/usr/local/share/npm/bin:/Users/joshvera/.cabal/bin:~/.lein/bin:/usr/local/bin:/usr/local/sbin:~/.rbenv/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X9/bin

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
function git(){hub "$@"}

# Give me my bash style incremental search
bindkey '^R' history-incremental-search-backward

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

function zle-line-init zle-keymap-select {
    export RPROMPT="${${KEYMAP/vicmd/[%*]}/main/-- INSERT --}"
    zle reset-prompt
}

function zle-line-finish {
    export RPROMPT='[%*]'
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select
zle -N zle-line-finish
export RPROMPT='[%*]'

bindkey -M viins '' backward-char
bindkey -M viins '' forward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins 'jj' vi-cmd-mode

# Rbenv
eval "$(rbenv init -)"

export TERM="xterm-256color"

