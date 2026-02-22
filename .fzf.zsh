# Setup fzf
# ---------
if command -v fzf >/dev/null 2>&1; then
  if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
    PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
  fi

  source <(fzf --zsh)
fi
