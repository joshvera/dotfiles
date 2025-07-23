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
  # Get project name and create consistent worktree naming
  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
  WORKTREE_NAME="${PROJECT_NAME}-${BRANCH_NAME}"
  WORKTREE_PATH="../$WORKTREE_NAME"

  # 1. Create the git worktree
  git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" HEAD

  # 2. Create a new Zellij tab, cd into the worktree, and name the tab
  zellij action new-tab --name "$BRANCH_NAME" --cwd "$WORKTREE_PATH" --layout single-bar
  
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

# Enhanced fzf branch picker - auto-creates worktrees and tabs
function fzf-branch-picker() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repository"
    return 1
  fi

  if ! command -v fzf >/dev/null; then
    echo "fzf not found - install for branch picking"
    return 1
  fi

  # Get all git branches (local and remote) and existing worktrees
  local branches worktrees combined_list project_name
  project_name=$(basename "$(git rev-parse --show-toplevel)")
  branches=$(git branch -a | sed 's/^..//; s/remotes\/origin\///' | sort -u | grep -v '^HEAD')
  worktrees=$(git worktree list --porcelain | grep "^worktree" | sed 's/^worktree //' | xargs -I {} basename {} 2>/dev/null | grep -v "$(basename $(pwd))" | sed "s/^${project_name}-//")
  
  # Combine branches and mark existing worktrees
  combined_list=""
  while IFS= read -r branch; do
    if echo "$worktrees" | grep -q "^${branch}$"; then
      combined_list="${combined_list}🌳 ${branch} (worktree)\n"
    else
      combined_list="${combined_list}${branch}\n"
    fi
  done <<< "$branches"
  
  echo "DEBUG: About to run fzf with combined_list:"
  echo -e "$combined_list" | head -5
  echo "DEBUG: Running fzf command..."
  
  local selection fzf_exit_code
  selection=$(echo -e "$combined_list" | fzf \
    --prompt="Branch/Worktree: " \
    --print-query \
    --expect=enter \
    --header="Enter to create/switch to worktree, Esc to cancel" \
    --height=15 \
    --reverse \
    --border)
  fzf_exit_code=$?

  echo "DEBUG: fzf exit code: $fzf_exit_code"
  if [ $fzf_exit_code -ne 0 ]; then
    echo "DEBUG: fzf cancelled or failed with exit code $fzf_exit_code"
    return 1
  fi
  
  echo "DEBUG: fzf selection raw output:"
  echo "'$selection'"

  local query key branch_line branch_name
  query=$(echo "$selection" | sed -n '1p')
  key=$(echo "$selection" | sed -n '2p')
  branch_line=$(echo "$selection" | sed -n '3p')

  # Extract branch name from selection (remove emoji and worktree indicator)
  echo "DEBUG: query='$query', key='$key', branch_line='$branch_line'"
  if [ -n "$branch_line" ]; then
    branch_name=$(echo "$branch_line" | sed 's/^🌳 //; s/ (worktree)$//')
    echo "DEBUG: Using branch_line, branch_name='$branch_name'"
  elif [ -n "$query" ]; then
    branch_name="$query"
    echo "DEBUG: Using query, branch_name='$branch_name'"
  else
    echo "DEBUG: No valid branch name found, returning"
    return 1
  fi

  # Get project name and create worktree path
  local project_name worktree_name worktree_path
  project_name=$(basename "$(git rev-parse --show-toplevel)")
  worktree_name="${project_name}-${branch_name}"
  worktree_path="../$worktree_name"

  # Check if worktree already exists
  echo "DEBUG: Checking worktree_path='$worktree_path'"
  if [ -d "$worktree_path" ]; then
    echo "Switching to existing worktree: $branch_name"
    echo "DEBUG: Creating new tab for existing worktree"
    # Always create a new tab for existing worktrees (switching is unreliable)
    zellij action new-tab --name "$branch_name" --cwd "$worktree_path" --layout single-bar
    echo "DEBUG: Created new tab for existing worktree"
  else
    # Create new worktree and tab
    echo "Creating worktree and tab for: $branch_name"
    
    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      # Branch exists locally - create worktree from it
      git worktree add "$worktree_path" "$branch_name"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
      # Remote branch exists - create local branch and worktree
      git worktree add -b "$branch_name" "$worktree_path" "origin/$branch_name"
    else
      # New branch - create it and worktree
      git worktree add -b "$branch_name" "$worktree_path" HEAD
    fi
    
    # Create new zellij tab
    zellij action new-tab --name "$branch_name" --cwd "$worktree_path" --layout single-bar
    echo "Created worktree '$branch_name' and corresponding tab"
  fi
}