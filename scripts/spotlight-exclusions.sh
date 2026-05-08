#!/usr/bin/env bash
# Exclude high-churn developer directories from Spotlight indexing.
# Drops .metadata_never_index marker files so Spotlight skips these paths.
# Safe to re-run; only touches directories that exist.

set -euo pipefail

dirs=(
  "$HOME/.codex"
  "$HOME/.claude"
  "$HOME/.cargo"
  "$HOME/.rustup"
  "$HOME/.npm"
  "$HOME/.pnpm-store"
  "$HOME/.local/share/pnpm"
  "$HOME/.pyenv"
  "$HOME/.local/share/virtualenvs"
  "$HOME/.rbenv"
  "$HOME/.rvm"
  "$HOME/.gradle"
  "$HOME/.m2"
  "$HOME/.docker"
  "$HOME/.bun"
  "$HOME/.deno"
  "$HOME/.volta"
  "$HOME/.nvm"
  "$HOME/.asdf"
  "$HOME/.miniconda3"
  "$HOME/.anaconda3"
  "$HOME/go/pkg"
  "$HOME/Library/Developer"
  "$HOME/Library/Caches"
  "$HOME/Library/Application Support/Code"
)

excluded=0
for dir in "${dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    touch "$dir/.metadata_never_index"
    echo "excluded: $dir"
    ((excluded += 1))
  fi
done

echo "spotlight exclusions: $excluded directories marked"
