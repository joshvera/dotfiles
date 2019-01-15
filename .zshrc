# so secret
source ~/.secrets/.secrets
 export KUBECONFIG=~/.secrets/assets/auth/kubeconfig

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

# Enable rbenv before path!
eval "$(rbenv init -)"

export GOPATH=/Users/vera/go

export PROJECTS=~/github

# Enable gpg-agent daemon
eval `gpg-agent --daemon --no-grab`

# Set gpg-agent info
export GPG_TTY=`tty`
export GPG_AGENT_INFO

# setup opam env
eval `opam config env`

fpath=(/usr/local/share/zsh-completions $fpath)

# Get rid of fzf?
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Try autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# Stack autocompletion
autoload -U +X bashcompinit && bashcompinit
eval "$(stack --bash-completion-script stack)"
