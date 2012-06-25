# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh
# Themes in ~/.oh-my-zsh/themes/
export ZSH_THEME="fwalch"

# Example aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git vi-mode)

source $ZSH/oh-my-zsh.sh

# Flags for package installations
export CFLAGS="-Os"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="-j9"

# Homebrew flags
export HOMEBREW_USE_CLANG

# Things I don't want to publish to github
source ~/.secrets


export CLOJURESCRIPT_HOME=/Users/joshvera/vendor/clojurescript
export PATH=~/.rbenv/shims:/Users/joshvera/vendor/WebKit/Tools/Scripts:/usr/local/Cellar/node/0.4.12/bin:/Applications/Emacs.app/Contents/MacOS/bin:/usr/local/share/npm/bin:/Users/joshvera/.cabal/bin:~/.lein/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X9/bin
export PATH=$PATH:$CLOJURESCRIPT_HOME/bin:$CLOJURESCRIPT_HOME/script

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

bindkey -M viins '
' backward-char
bindkey -M viins '' forward-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^e' end-of-line
bindkey -M viins 'jj' vi-cmd-mode

export TERM=xterm-256color

if [ -n "$INSIDE_EMACS" ]; then
    chpwd() { print -P "\033AnSiTc %d" }
    print -P "\033AnSiTu %n"
    print -P "\033AnSiTc %d"
fi

export YABBLY_HOME="/Users/joshvera/Projects/Yabbly/yabbly-home"

alias pgstart='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pgstop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

export PATH=/Applications/Xcode45-DP1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:/Applications/Xcode45-DP1.app/Contents/Developer/usr/bin:$PATH

if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
