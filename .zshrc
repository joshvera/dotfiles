# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Path to oh-my-zsh configuration
export ZSH=$HOME/.oh-my-zsh

# Oh my zsh theme
export ZSH_THEME="powerlevel10k/powerlevel10k"

# Performance optimizations
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

# Plugins
plugins=(vi-mode brew coffee pip git fzf github)

# Term
export TERM=xterm-256color
export ZSH_DISABLE_COMPFIX=true

# Oh my zsh
source $ZSH/oh-my-zsh.sh

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Optimized completion loading
autoload -Uz compinit
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
    compinit
else
    compinit -C
fi
autoload -U +X bashcompinit && bashcompinit

# Conditional expensive completions
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh)
fi

if command -v idris2 >/dev/null 2>&1; then
    eval "$(idris2 --bash-completion-script idris2)"
fi

# Source secrets
source ~/.secrets/.secrets

# Add dotfiles bin to PATH
export PATH="$HOME/github/dotfiles/bin:$PATH"

source ~/github/dotfiles/zsh/aliases

bindkey '^F' forward-char
bindkey '^B' backward-char
bindkey 'ƒ' forward-word    # Alt+Right
bindkey '∫' backward-word   # Alt+Left
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^Y' yank

eval "$(mise activate zsh)"
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Sync history to bash for Termius autocomplete
function sync_history_to_bash() {
    if [[ -f ~/.zsh_history ]]; then
        sed 's/^: [0-9]*:[0-9]*;//' ~/.zsh_history > ~/.bash_history 2>/dev/null
    fi
}

# Auto-sync after every command
autoload -U add-zsh-hook
add-zsh-hook precmd sync_history_to_bash

# Also sync on exit
trap sync_history_to_bash EXIT
