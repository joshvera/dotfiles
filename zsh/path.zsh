# Deterministic PATH ordering shared by all Zsh startup modes.
_vera_apply_path_order() {
  typeset -gU path PATH
  local -a preferred_paths=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/share/mise/shims"
    "$HOME/github/dotfiles/bin"
    "$HOME/github/dotfiles/tmux"
    "$HOME/.claude-native/scripts"
    "$HOME/Library/pnpm"
    "$HOME/.npm/bin"
    "$HOME/.nodenv/shims"
    "$HOME/.poetry/bin"
    "$HOME/.pack/bin"
    "$HOME/.bun/bin"
    "$HOME/.ghcup/bin"
    "$HOME/.cabal/bin"
    "$HOME/go/bin"
    "${KREW_ROOT:-$HOME/.krew}/bin"
    "$HOME/.lmstudio/bin"
    "$HOME/github/ralph-playbook/files"
    "$HOME/github/HoTT"
    "/Applications/Isabelle2018.app/Isabelle/bin"
    "/opt/homebrew/opt/mysql@5.7/bin"
    "/opt/homebrew/opt/libpq/bin"
    "/opt/homebrew/opt/postgresql@15/bin"
    "/opt/homebrew/bin"
    "$HOME/miniconda3/bin"
    "/opt/homebrew/anaconda3/bin"
  )

  path=("${preferred_paths[@]}" "${path[@]}")
  export PATH
}

_vera_apply_path_order
