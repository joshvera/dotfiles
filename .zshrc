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

# Oh my zsh theme
export ZSH_THEME="powerlevel10k/powerlevel10k"

# Performance optimizations
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

# Zsh autosuggestions: Mobile-optimized configuration (BEFORE Oh My Zsh)
# Priority: history first (command recall), then completion (file exploration)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Performance optimizations for mobile SSH
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_USE_ASYNC=true

# Optional: skip costly completion for heavy commands
export ZSH_AUTOSUGGEST_COMPLETION_IGNORE='git|kubectl|npm'

# Visible highlight style for ghost text (mobile-friendly)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

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

# Plugins - Critical order: fzf-tab BEFORE zsh-autosuggestions
plugins=(vi-mode brew coffee pip git fzf github fzf-tab zsh-autosuggestions)

# Term
export TERM=xterm-256color
export ZSH_DISABLE_COMPFIX=true

# Oh my zsh
source $ZSH/oh-my-zsh.sh

# ----------------------------------------------------------------------
# Predictive Completion: Smart prediction for common command patterns
# Shows ghost text for likely next arguments before fzf-tab activation
# ----------------------------------------------------------------------
function _predict_completion {
  local cmd="$1" partial_arg="$2"
  
  case "$cmd" in
    "git")
      local -a git_words
      git_words=("${(z)LBUFFER}")
      
      # Handle git subcommands
      if (( ${#git_words[@]} >= 2 )); then
        local subcommand="${git_words[2]}"
        case "$subcommand" in
          "commit")
            # git commit flag prediction: -m > -a > --amend
            case "$partial_arg" in
              "--a"*) echo "--amend" ;;
              "-m"|"-"*"m"*) echo "-m" ;;
              "-a"|"-"*"a"*) echo "-a" ;;  
              "-"*) echo "-m" ;;  # Default to most common
              *) ;;
            esac
            ;;
          "checkout"|"switch")
            # Could predict branch names, but keep simple for now
            ;;
        esac
      fi
      ;;
  esac
}

# ----------------------------------------------------------------------
# Context-Aware Smart Tab: Intelligent completion based on command context
# - Command context (first word): Accept ghost text for command recall
# - Argument context (after space): Show fzf-tab for files/options
# - Predictive enhancement: Shows likely completions as ghost text first
# Mobile SSH optimized with predictable, low-latency logic.
# ----------------------------------------------------------------------
function _smart_tab_handler {
  [[ -o zle ]] || return

  # If a region is active, default to standard completion
  if [[ ${REGION_ACTIVE:-0} -ne 0 ]]; then
    zle expand-or-complete
    return
  fi

  # Split the buffer to the left of the cursor into words
  local -a words
  words=("${(z)LBUFFER}")

  # Context detection: Are we completing arguments or the command itself?
  # If more than one word OR first word complete + trailing space → argument context
  if (( ${#words[@]} > 1 )) || [[ -n ${words[1]} && $LBUFFER[-1] == ' ' ]]; then
    # ARGUMENT CONTEXT: Check for predictive completion first
    local prediction=""
    if (( ${#words[@]} >= 2 )); then
      local cmd="${words[1]}"
      local current_arg="${words[-1]}"
      
      # Try predictive completion for common patterns
      prediction="$(_predict_completion "$cmd" "$current_arg")"
      
      # If we have a prediction and no existing ghost text, show it
      if [[ -n "$prediction" && -z "$POSTDISPLAY" ]]; then
        # Set ghost text to show the prediction
        local remaining="${prediction#$current_arg}"
        if [[ -n "$remaining" ]]; then
          POSTDISPLAY="$remaining"
          region_highlight+=("$CURSOR $(($CURSOR + ${#remaining})) fg=240")
          return
        fi
      fi
    fi
    
    # If prediction didn't work or user wants to explore → show fzf-tab
    local _c
    for _c in fzf-tab-complete fzf-completion; do
      (( $+widgets[$_c] )) && { zle $_c; return }
    done
  fi

  # COMMAND CONTEXT: Accept high-quality suggestions (command recall)
  if [[ -n $POSTDISPLAY ]]; then
    zle autosuggest-accept
    return
  fi

  # Fallback to fzf-tab if no suggestion was accepted
  local _c
  for _c in fzf-tab-complete fzf-completion; do
    (( $+widgets[$_c] )) && { zle $_c; return }
  done

  # Final fallback to zsh's default completion
  for _c in expand-or-complete-prefix expand-or-complete complete-word; do
    zle -l | grep -qx "$_c" && { zle "$_c"; return }
  done
}

zle -N _smart_tab_handler
bindkey '^I' _smart_tab_handler        # emacs keymap
bindkey -M viins '^I' _smart_tab_handler  # vi insert keymap

# ----------------------------------------------------------------------
# Smart Space: Auto-trigger fzf completion for argument context  
# Only trigger when NO ghost text is available (preserves autosuggestions)
# ----------------------------------------------------------------------
function _smart_space_handler {
  [[ -o zle ]] || return
  
  # Store current state before inserting space
  local pre_space_buffer="$LBUFFER"
  local -a pre_words
  pre_words=("${(z)pre_space_buffer}")
  
  # Always insert the space first
  zle self-insert
  
  # Trigger autosuggestion refresh after space insertion
  if (( $+widgets[autosuggest-fetch] )); then
    zle autosuggest-fetch
  fi
  
  # Small delay to let autosuggestions process, then check if we should auto-complete
  # Only trigger in mobile/SSH sessions AND only if no ghost text appeared
  if [[ -n "$SSH_CLIENT" || -n "$SSH_CONNECTION" ]]; then
    # If we just completed the first word (command) and still no autosuggestion exists
    if (( ${#pre_words[@]} == 1 )) && [[ -n ${pre_words[1]} ]] && [[ -z "$POSTDISPLAY" ]]; then
      # Try to trigger fzf-tab completion
      local _c
      for _c in fzf-tab-complete fzf-completion; do
        if (( $+widgets[$_c] )); then
          zle $_c
          return
        fi
      done
      # Fallback to standard completion
      zle expand-or-complete
    fi
  fi
}

zle -N _smart_space_handler
bindkey ' ' _smart_space_handler          # emacs keymap  
bindkey -M viins ' ' _smart_space_handler # vi insert keymap

# Conditional Ctrl+F for mobile (SSH sessions) - AFTER Oh My Zsh
if [[ -n "$SSH_CLIENT" || -n "$SSH_CONNECTION" ]]; then
    # Mobile/SSH session detected - enable Ctrl+F for autosuggestions
    bindkey '^f' autosuggest-accept
    
    # Ensure autosuggestion strategy is set correctly after plugin loading
    # Priority: history first (command recall), then completion (file exploration)
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    
    # Mobile fzf-tab navigation help (Tab=accept, Shift-Tab=cycle)
    echo "📱 Mobile mode active: Tab=accept, Shift-Tab=cycle, Ctrl+j/k=nav"
    echo "🔄 Autosuggestion strategy: ${ZSH_AUTOSUGGEST_STRATEGY[@]}"
fi

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

# Add dotfiles bin to PATH
export PATH="$HOME/github/dotfiles/bin:$PATH"

source ~/github/dotfiles/zsh/aliases

# bindkey '^F' forward-char  # Disabled - conflicts with zsh-autosuggestions Ctrl+F
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

