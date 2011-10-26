# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh
# Themes in ~/.oh-my-zsh/themes/
export ZSH_THEME="robbyrussell"

source $ZSH/oh-my-zsh.sh

# Paths
export PATH=/usr/local/Cellar/node/0.4.12/bin:/Applications/Emacs.app/Contents/MacOS/bin:~/.rbenv/bin:/usr/local/share/npm/bin:~/.cabal/bin:~/.lein/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:$PATH

export VIM_APP_DIR=/Applications
export NODE_PATH=/usr/local/lib/node

alias emacs='open -a /Applications/Emacs.app $@'
export EDITOR="mvim"
export VISUAL='mvim -f'
# Git aliases
alias gsb="git submodule "
alias g="git "
alias grc='git rebase --continue'
alias gra='git rebase --abort'
alias gs='git status '
alias gst='git status '
alias ga='git add'
alias gb='git branch'
alias gba='git branch -a'
alias gc='git commit -v'
alias gcm='git commit -v -m'
alias gca='git commit -v -a'
alias gd='git diff --color'
alias go='git checkout'
alias gl='git log'
alias gv='git status | pru  --reduce '"'"'select {|s| s.match(/#\s+modified:.+/) }.map {|s| s.gsub(/#\s+modified:\s+/, "") }.first'"' | xargs vim"
alias got='git '
alias get='git '
alias sporkify='bundle exec spork cucumber & bundle exec spork'

AUTOFEATURE='true'

export JAVA_OPTS=-Xmx768m
alias vim="mvim -v"
eval "$(rbenv init -)"
