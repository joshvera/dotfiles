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
export ZSH_CUSTOM="/Users/vera/github/dotfiles/zsh"

# Add custom functions to fpath
fpath=($ZSH_CUSTOM/functions $fpath)
autoload -U $ZSH_CUSTOM/functions/*

# Oh my zsh theme
export ZSH_THEME="powerlevel10k/powerlevel10k"

# Performance optimizations
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"


# fzf-tab mobile optimizations (BEFORE Oh My Zsh)
# Toggle fzf-tab for performance when needed
zstyle ':fzf-tab:*' switch-group ',' '.'
# Disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# Set descriptions format for fzf-tab
zstyle ':completion:*:descriptions' format '[%d]'
# Set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'

# Mobile-conditional fzf-tab navigation: Tab-to-accept for SSH sessions
if [[ -n "$SSH_CLIENT" || -n "$SSH_CONNECTION" ]]; then
    # Mobile/SSH: Tab accepts, Shift-Tab cycles, arrows still work  
    zstyle ':fzf-tab:*' fzf-bindings 'tab:accept,shift-tab:down,ctrl-j:down,ctrl-k:up'
else
    # Desktop: Keep standard Tab-cycling behavior
    zstyle ':fzf-tab:*' fzf-bindings 'tab:down,ctrl-j:down,ctrl-k:up'
fi

# ----------------------------------------------------------------------
# Intelligent Completion Prioritization: Configure zsh completion system
# to prioritize common options. zsh-autosuggestions will automatically 
# pick up the highest-priority completion as ghost text.
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Command-Specific Completion Prioritization
# Configure high-priority options for common commands so zsh-autosuggestions
# shows the most useful flags as ghost text
# ----------------------------------------------------------------------

# Git: prioritize common flags by subcommand
zstyle ':completion:*:*:git-commit:*' tag-order 'options'
zstyle ':completion:*:*:git-commit:*:options' order '-m --message -a --all --amend'
zstyle ':completion:*:*:git-checkout:*' tag-order 'options'
zstyle ':completion:*:*:git-checkout:*:options' order '-b --branch -t --track'
zstyle ':completion:*:*:git-push:*' tag-order 'options'  
zstyle ':completion:*:*:git-push:*:options' order '-u --set-upstream -f --force'

# Docker: prioritize common flags
zstyle ':completion:*:*:docker-run:*' tag-order 'options'
zstyle ':completion:*:*:docker-run:*:options' order '-d --detach -p --publish -v --volume'
zstyle ':completion:*:*:docker-exec:*' tag-order 'options'
zstyle ':completion:*:*:docker-exec:*:options' order '-it -d --detach'

# npm: prioritize common flags
zstyle ':completion:*:*:npm-install:*' tag-order 'options'
zstyle ':completion:*:*:npm-install:*:options' order '--save-dev -D --global -g'
zstyle ':completion:*:*:npm-run:*' tag-order 'options'

# kubectl: prioritize common flags  
zstyle ':completion:*:*:kubectl-get:*' tag-order 'options'
zstyle ':completion:*:*:kubectl-get:*:options' order '-o --output -w --watch'
zstyle ':completion:*:*:kubectl-apply:*' tag-order 'options'
zstyle ':completion:*:*:kubectl-apply:*:options' order '-f --filename'

# ls/cat: prioritize useful flags
zstyle ':completion:*:*:ls:*' tag-order 'options'
zstyle ':completion:*:*:ls:*:options' order '-la -l --long -a --all'
zstyle ':completion:*:*:cat:*' tag-order 'options'
zstyle ':completion:*:*:cat:*:options' order '-n --number-lines -v --show-nonprinting'

# General: prioritize options over files for predictable ghost text
zstyle ':completion:*' group-order 'options arguments files'

# Plugins - fzf-tab for enhanced completion
plugins=(vi-mode brew coffee pip git fzf github fzf-tab)

# Term
export TERM=xterm-256color
export ZSH_DISABLE_COMPFIX=true

# Oh my zsh
source $ZSH/oh-my-zsh.sh

# ----------------------------------------------------------------------
# Simple Tab: Use fzf-tab for enhanced completion
# ----------------------------------------------------------------------
function _smart_tab_handler {
  [[ -o zle ]] || return
  
  # Trigger fzf-tab completion
  if (( $+widgets[fzf-tab-complete] )); then
    zle fzf-tab-complete
  else
    # Fallback to standard completion if fzf-tab not available
    zle expand-or-complete
  fi
}

zle -N _smart_tab_handler
bindkey '^I' _smart_tab_handler        # emacs keymap
bindkey -M viins '^I' _smart_tab_handler  # vi insert keymap



# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Optimized completion loading (REMOVED - Oh My Zsh already handles compinit)
# autoload -Uz compinit
# if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
#     compinit
# else
#     compinit -C
# fi
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

# PATH Configuration moved to .zshenv for better shell compatibility

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


# Claude-Native integration
export CLAUDE_NATIVE_HOME="$HOME/.claude-native"
export PATH="$CLAUDE_NATIVE_HOME/scripts:$PATH"

# Auto-sync on directory change (optional)
claude_native_cd() {
    builtin cd "$@" && {
        if [[ -x "$CLAUDE_NATIVE_HOME/scripts/claude-native" ]]; then
            "$CLAUDE_NATIVE_HOME/scripts/claude-native" sync --quiet 2>/dev/null || true
        fi
    }
}

# Enable auto-sync (uncomment to activate)
# alias cd="claude_native_cd"


# pnpm
export PNPM_HOME="/Users/vera/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/vera/.lmstudio/bin"
# End of LM Studio CLI section

export SSH_AUTH_SOCK=/Users/vera/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh 

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/vera/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

op-wintermute() {
  export OP_SERVICE_ACCOUNT_TOKEN="$(op item get 'Service Account Auth Token: Wintermute' --vault Personal --fields credential --reveal)"
  echo "1Password Wintermute service account activated"
}
