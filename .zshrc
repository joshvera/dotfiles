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

# Enable rbenv before path!
eval "$(rbenv init -)"

# PATH
export PATH=~/.cabal/bin:~/.cargo/bin:/usr/local/texlive/2017/bin/x86_64-darwin:/Users/vera/miniconda3/bin:~/.local/bin:$PATH:/Users/vera/go/bin
export GOPATH=/Users/vera/go

# Enable gpg-agent daemon
if test -f $HOME/.gpg-agent-info && kill -0 `cut -d: -f 2 $HOME/.gpg-agent-info` 2>/dev/null; then
    GPG_AGENT_INFO=`cat $HOME/.gpg-agent-info | cut -c 16-`
else
    # No, gpg-agent not available; start gpg-agent
    eval `gpg-agent --daemon --no-grab --write-env-file $HOME/.gpg-agent-info`
fi

# Set gpg-agent info
export GPG_TTY=`tty`
export GPG_AGENT_INFO

# setup opam env
eval `opam config env`

fpath=(/usr/local/share/zsh-completions $fpath)

# Get rid of fzf?
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
