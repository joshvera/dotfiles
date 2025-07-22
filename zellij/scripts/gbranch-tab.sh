#!/bin/bash
# Shell helper functions for zellij git worktree workflow
# Add to your ~/.zshrc or ~/.bashrc:
# source ~/github/dotfiles/zellij/scripts/gbranch-tab.sh

# Renames the current Zellij tab to the current git branch name.
# If not in a git repo, names it after the current directory.
function gbranch_tab() {
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch_name" ]]; then
    zellij action rename-tab "$branch_name"
  else
    # Fallback for non-git directories
    zellij action rename-tab "${PWD##*/}"
  fi
}

# Create new worktree and corresponding Zellij tab
function new-work() {
  if [ -z "$1" ]; then
    echo "Usage: new-work <branch-name>"
    return 1
  fi

  BRANCH_NAME=$1
  # Adjust path as needed - assumes you run from main worktree
  WORKTREE_PATH="../$BRANCH_NAME"

  # 1. Create the git worktree
  git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" HEAD

  # 2. Create a new Zellij tab, cd into the worktree, and name the tab
  zellij action new-tab --name "$BRANCH_NAME" --cwd "$WORKTREE_PATH"
  
  echo "Created worktree '$BRANCH_NAME' and corresponding tab"
}

# Quick tab switch by name (fuzzy search)
function zt() {
  if command -v fzf >/dev/null; then
    zellij action go-to-tab-name "$(zellij list-sessions -s | grep -o 'Tab #[0-9]*: [^,]*' | cut -d' ' -f3- | fzf)"
  else
    echo "fzf not found - install for fuzzy tab switching"
  fi
}