#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/github/dotfiles}"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$DOTFILES_DIR/skills" ]]; then
  echo "skills dir not found: $DOTFILES_DIR/skills" >&2
  exit 1
fi

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "${target}.pre-dotfiles-${STAMP}"
    echo "backed up $target -> ${target}.pre-dotfiles-${STAMP}"
  fi
}

link_skill() {
  local src="$1"
  local runtime_dir="$2"
  local name
  local dst

  name="$(basename "$src")"
  dst="$runtime_dir/$name"

  mkdir -p "$runtime_dir"
  backup_if_needed "$dst"
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

for skill_dir in "$DOTFILES_DIR"/skills/*; do
  [[ -d "$skill_dir" ]] || continue
  link_skill "$skill_dir" "$HOME/.claude/skills"
  link_skill "$skill_dir" "$HOME/.codex/skills"
done

echo "synced AI skills"
