#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/github/dotfiles}"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "dotfiles dir not found: $DOTFILES_DIR" >&2
  exit 1
fi

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "${target}.pre-dotfiles-${STAMP}"
    echo "backed up $target -> ${target}.pre-dotfiles-${STAMP}"
  fi
}

link_file() {
  local src="$1"
  local dst="$2"
  backup_if_needed "$dst"
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

# Core shell files
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# Tmux config (new path first, legacy fallback)
TMUX_SRC="$DOTFILES_DIR/tmux/tmux.conf"
if [[ ! -f "$TMUX_SRC" && -f "$DOTFILES_DIR/.tmux.conf" ]]; then
  TMUX_SRC="$DOTFILES_DIR/.tmux.conf"
fi
if [[ -f "$TMUX_SRC" ]]; then
  link_file "$TMUX_SRC" "$HOME/.tmux.conf"
else
  echo "skip ~/.tmux.conf: no tmux config found in $DOTFILES_DIR" >&2
fi

# Optional gitconfig
if [[ "${1:-}" == "--with-gitconfig" ]]; then
  if [[ -f "$DOTFILES_DIR/.gitconfig" ]]; then
    link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
  else
    echo "skip ~/.gitconfig: $DOTFILES_DIR/.gitconfig not found"
  fi
fi

# fzf shell integration (if installed)
if command -v fzf >/dev/null 2>&1; then
  if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
  fi
fi

echo "done"
