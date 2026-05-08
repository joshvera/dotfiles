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
  mkdir -p "$(dirname "$dst")"
  backup_if_needed "$dst"
  if [[ -L "$dst" ]]; then
    rm -f "$dst"
  fi
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

# Git config (canonical in dotfiles when present)
if [[ -f "$DOTFILES_DIR/.gitconfig" ]]; then
  link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
else
  echo "skip ~/.gitconfig: $DOTFILES_DIR/.gitconfig not found"
fi

# fzf shell setup tracked in dotfiles
if [[ -f "$DOTFILES_DIR/.fzf.zsh" ]]; then
  link_file "$DOTFILES_DIR/.fzf.zsh" "$HOME/.fzf.zsh"
fi

# Shared agent skills
mkdir -p "$HOME/.agents"
link_file "$DOTFILES_DIR/.agents/skills" "$HOME/.agents/skills"

# Codex-specific/system skills
mkdir -p "$HOME/.codex"
mkdir -p "$DOTFILES_DIR/.codex/skills"
link_file "$DOTFILES_DIR/.codex/skills" "$HOME/.codex/skills"

link_external_gstack() {
  local gstack_root="$HOME/.gstack/repos/gstack"
  local target="$DOTFILES_DIR/.agents/skills/gstack"

  [[ -d "$gstack_root/.git" ]] || return 0

  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "gstack skill target is a real directory, not replacing: $target" >&2
    echo "Move it aside, then rerun bootstrap to link $target -> $gstack_root" >&2
    exit 1
  fi

  rm -f "$target"
  ln -s "$gstack_root" "$target"
  echo "linked $target -> $gstack_root"
}

# Expose repo-owned shared skills to Codex without duplicating the source.
if [[ -d "$DOTFILES_DIR/.agents/skills" && -d "$DOTFILES_DIR/.codex/skills" ]]; then
  shared_skills=(
    codex-planner
    codex-review
    find-skills
    gh-address-comments
    gws-cli
    playwriter
    qodo-pr-resolver
    sem
    skill-creator
  )
  for skill_name in "${shared_skills[@]}"; do
    [[ -d "$DOTFILES_DIR/.agents/skills/$skill_name" ]] || continue
    target="$DOTFILES_DIR/.codex/skills/$skill_name"
    rm -rf "$target"
    ln -s "../../.agents/skills/$skill_name" "$target"
  done

  link_external_gstack

  # Preserve Claude visibility for generated Codex-only skills while keeping
  # those generated installs out of Git. gstack is managed by upstream setup:
  # Claude needs its root skill to resolve to the git checkout for auto-update.
  for skill_path in "$DOTFILES_DIR"/.codex/skills/*; do
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    [[ -e "$skill_path" || -L "$skill_path" ]] || continue
    [[ "$skill_name" == "gstack" ]] && continue
    if [[ "$skill_name" == gstack-* ]]; then
      resolved="$(
        cd "$skill_path" 2>/dev/null && pwd -P
      )"
      [[ "$resolved" == "$HOME/.gstack/repos/gstack"* ]] || continue
    fi
    [[ -e "$DOTFILES_DIR/.agents/skills/$skill_name" && ! -L "$DOTFILES_DIR/.agents/skills/$skill_name" ]] && continue
    ln -sfn "../../.codex/skills/$skill_name" "$DOTFILES_DIR/.agents/skills/$skill_name"
  done
fi

# Claude Code config
# If ~/.claude already points into the dotfiles repo, skip individual links
# (hooks live directly in .claude/hooks/, skills symlink is committed to the repo)
if [[ "$(readlink "$HOME/.claude" 2>/dev/null)" == "$DOTFILES_DIR/.claude" ]]; then
  echo "~/.claude already linked to $DOTFILES_DIR/.claude"
  # Ensure the skills symlink inside the repo points to .agents/skills
  if [[ ! -L "$DOTFILES_DIR/.claude/skills" ]]; then
    ln -sfn "$HOME/.agents/skills" "$DOTFILES_DIR/.claude/skills"
    echo "linked $DOTFILES_DIR/.claude/skills -> $HOME/.agents/skills"
  fi
else
  mkdir -p "$HOME/.claude"
  link_file "$DOTFILES_DIR/.claude/hooks" "$HOME/.claude/hooks"
  link_file "$HOME/.agents/skills" "$HOME/.claude/skills"
fi

# Ensure fzf itself is installed and generate baseline if missing
if command -v fzf >/dev/null 2>&1; then
  if [[ ! -f "$DOTFILES_DIR/.fzf.zsh" ]] && [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    cp "$HOME/.fzf.zsh" "$DOTFILES_DIR/.fzf.zsh" || true
    link_file "$DOTFILES_DIR/.fzf.zsh" "$HOME/.fzf.zsh"
  fi
fi

# Spotlight exclusions for developer directories
if [[ "$(uname)" == "Darwin" ]]; then
  "$DOTFILES_DIR/scripts/spotlight-exclusions.sh" || echo "warning: spotlight exclusions failed" >&2
fi

echo "done"
