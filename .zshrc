# # Enable rbenv before path!
# eval "$(rbenv init -)"


# # Enable gpg-agent daemon
# if test -f $HOME/.gpg-agent-info && kill -0 `cut -d: -f 2 $HOME/.gpg-agent-info` 2>/dev/null; then
#     GPG_AGENT_INFO=`cat $HOME/.gpg-agent-info | cut -c 16-`
# else
#     # No, gpg-agent not available; start gpg-agent
#     eval `gpg-agent --daemon --no-grab`
# fi

## Enable rbenv before path!
eval "$(rbenv init -)"

# setup opam env
eval `opam config env`

# Stack autocompletion
autoload -U +X bashcompinit && bashcompinit
eval "$(stack --bash-completion-script stack)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
