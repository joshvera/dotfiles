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
  project_name=$(basename -s .git "$(git config --get remote.origin.url)")
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
  
  local selection fzf_exit_code
  selection=$(echo -e "$combined_list" | fzf \
    --prompt="Branch/Worktree: " \
    --print-query \
    --expect=enter \
    --header="Enter to create/switch to worktree, Esc to cancel" \
    --height=15 \
    --reverse \
    --border \
    --no-sort)
  fzf_exit_code=$?

  # fzf returns 1 when no selection is made, but we might still have a query
  if [ $fzf_exit_code -eq 130 ]; then
    return 1
  fi

  local query key branch_line branch_name
  query=$(echo "$selection" | sed -n '1p')
  key=$(echo "$selection" | sed -n '2p')
  branch_line=$(echo "$selection" | sed -n '3p')

  # Extract branch name from selection (remove emoji and worktree indicator)
  if [ -n "$branch_line" ]; then
    branch_name=$(echo "$branch_line" | sed 's/^🌳 //; s/ (worktree)$//')
  elif [ -n "$query" ]; then
    branch_name="$query"
  else
    return 1
  fi

  # Get project name and create worktree path
  local project_name branch_dir worktree_name worktree_path
  project_name=$(basename -s .git "$(git config --get remote.origin.url)")
  branch_dir=${branch_name//\//-}  # Replace '/' with '-' for valid directory names
  worktree_name="${project_name}-${branch_dir}"
  worktree_path="../$worktree_name"

  # Check if worktree already exists (try both sanitized and legacy unsanitized paths)
  local legacy_worktree_name legacy_worktree_path
  legacy_worktree_name="${project_name}-${branch_name}"
  legacy_worktree_path="../$legacy_worktree_name"
  
  if [ -d "$worktree_path" ]; then
    # Use sanitized path
    worktree_path="$worktree_path"
  elif [ -d "$legacy_worktree_path" ]; then
    # Use legacy unsanitized path for existing worktrees
    worktree_path="$legacy_worktree_path"
  fi
  
  if [ -d "$worktree_path" ]; then
    echo "Switching to existing worktree: $branch_name"
    local absolute_worktree_path
    absolute_worktree_path=$(realpath "$worktree_path")
    
    # Try to switch to existing tab first
    if zellij action go-to-tab-name "$branch_name" 2>/dev/null; then
      echo "Switched to existing tab: $branch_name"
      # Close the branch picker pane
      sleep 0.1
      zellij action close-pane
    else
      echo "No existing tab found, creating new tab"
      # Create the tab and change directory
      zellij action new-tab --layout single-bar --name "$branch_name"
      sleep 0.2
      zellij action write-chars "cd '$absolute_worktree_path' && clear"
      zellij action write 10
      # Close the branch picker pane on the original tab
      zellij action go-to-previous-tab
      zellij action close-pane
      zellij action go-to-tab-name "$branch_name"
    fi
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
    
    # Create new zellij tab and change directory
    local absolute_worktree_path
    absolute_worktree_path=$(realpath "$worktree_path")
    
    # Create the tab first
    zellij action new-tab --layout single-bar --name "$branch_name"
    # Send cd command to the new tab and clear the line to hide the command
    zellij action write-chars "cd '$absolute_worktree_path' && clear"
    # Send enter to execute the commands
    zellij action write 10  # 10 is the ASCII code for newline
    # Close the branch picker pane on the original tab
    zellij action go-to-previous-tab
    zellij action close-pane
    zellij action go-to-tab-name "$branch_name"
    echo "Created worktree '$branch_name' and corresponding tab"
  fi
}