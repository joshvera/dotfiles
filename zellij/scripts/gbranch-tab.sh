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

# Enhanced fzf branch picker - auto-creates branches if they don't exist
function fzf-branch-picker() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repository"
    return 1
  fi

  if ! command -v fzf >/dev/null; then
    echo "fzf not found - install for branch picking"
    return 1
  fi

  # Get all git branches (local and remote)
  local branches
  branches=$(git branch -a | sed 's/^..//; s/remotes\/origin\///' | sort -u | grep -v '^HEAD')
  
  local selection
  selection=$(echo "$branches" | fzf \
    --prompt="Branch: " \
    --print-query \
    --expect=enter \
    --header="Enter to checkout/create branch, Esc to cancel" \
    --height=15 \
    --reverse \
    --border)

  if [ $? -ne 0 ]; then
    return 1
  fi

  local query key branch_name
  query=$(echo "$selection" | sed -n '1p')
  key=$(echo "$selection" | sed -n '2p')
  branch_name=$(echo "$selection" | sed -n '3p')

  # If no branch was selected but query exists, use query as new branch name
  if [ -z "$branch_name" ] && [ -n "$query" ]; then
    branch_name="$query"
  elif [ -n "$branch_name" ]; then
    # Use selected branch
    branch_name="$branch_name"
  else
    return 1
  fi

  # Check if branch exists locally
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    echo "Switching to existing branch: $branch_name"
    git checkout "$branch_name"
  else
    # Check if it exists as a remote branch
    if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
      echo "Creating local branch from remote: $branch_name"
      git checkout -b "$branch_name" "origin/$branch_name"
    else
      echo "Creating new branch: $branch_name"
      git checkout -b "$branch_name"
    fi
  fi

  # Update zellij tab name to match branch
  gbranch_tab
}