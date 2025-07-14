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

# Plugins
plugins=(vi-mode brew coffee pip git fzf github)

# Term
export TERM=xterm-256color
export ZSH_DISABLE_COMPFIX=true

# Oh my zsh
source $ZSH/oh-my-zsh.sh

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Kubectl completion
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# Autoload
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit

# Idris2 completion
eval "$(idris2 --bash-completion-script idris2)"

# Source secrets
source ~/.secrets/.secrets

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

