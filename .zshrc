# so secret
source ~/.secrets

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
source ~/dotfiles/zsh/aliases
source ~/dotfiles/zsh/zsh_aliases

# PATH
export PATH=~/.local/bin:$PATH:/usr/local/opt/go/libexec/bin

# Enable rbenv
eval "$(rbenv init -)"

# Enable gpg-agent daemon
if test -f $HOME/.gpg-agent-info && kill -0 `cut -d: -f 2 $HOME/.gpg-agent-info` 2>/dev/null; then
    GPG_AGENT_INFO=`cat $HOME/.gpg-agent-info | cut -c 16-`
else
    # No, gpg-agent not available; start gpg-agent
    eval `gpg-agent --daemon --no-grab --write-env-file $HOME/.gpg-agent-info`
fi
export GPG_TTY=`tty`
export GPG_AGENT_INFO
