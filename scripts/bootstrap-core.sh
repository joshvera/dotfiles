#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/github/dotfiles}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OMX_REPO_URL="${OMX_REPO_URL:-https://github.com/joshvera/oh-my-codex.git}"
OMX_REPO_DIR="${OMX_REPO_DIR:-$HOME/github/oh-my-codex}"
GSTACK_REPO_URL="${GSTACK_REPO_URL:-https://github.com/garrytan/gstack.git}"
GSTACK_REPO_DIR="${GSTACK_REPO_DIR:-$HOME/.gstack/repos/gstack}"
SHARED_SKILLS=(
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

link_path() {
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

ensure_git_checkout() {
  local repo_url="$1"
  local repo_dir="$2"
  local branch="$3"
  local label="$4"

  if [[ -e "$repo_dir" && ! -d "$repo_dir/.git" ]]; then
    echo "$label path exists but is not a git checkout: $repo_dir" >&2
    exit 1
  fi

  if [[ ! -d "$repo_dir/.git" ]]; then
    mkdir -p "$(dirname "$repo_dir")"
    git clone --branch "$branch" "$repo_url" "$repo_dir"
    return
  fi

  git -C "$repo_dir" remote set-url origin "$repo_url"

  if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
    echo "skip updating $label checkout: local changes present in $repo_dir"
    return
  fi

  git -C "$repo_dir" fetch origin --prune --tags
  git -C "$repo_dir" checkout "$branch"
  git -C "$repo_dir" pull --ff-only origin "$branch"
}

install_omx_from_fork() {
  if [[ "${BOOTSTRAP_SKIP_OMX:-0}" == "1" ]]; then
    echo "skip OMX install/update: BOOTSTRAP_SKIP_OMX=1"
    return
  fi

  ensure_git_checkout "$OMX_REPO_URL" "$OMX_REPO_DIR" "main" "OMX"

  (
    cd "$OMX_REPO_DIR"
    npm install --package-lock=false
    npm run build
    npm install -g "$OMX_REPO_DIR"
  )

  omx setup --scope user --plugin
}

install_local_omx_plugin_cache() {
  local plugin_root="$OMX_REPO_DIR/plugins/oh-my-codex"
  local cache_root="$HOME/.codex/plugins/cache/oh-my-codex-local/oh-my-codex/local"

  if [[ ! -d "$plugin_root/.codex-plugin" ]]; then
    echo "skip OMX plugin cache install: missing plugin root at $plugin_root" >&2
    return
  fi

  mkdir -p "$(dirname "$cache_root")"

  if [[ -L "$cache_root" ]]; then
    rm -f "$cache_root"
  elif [[ -e "$cache_root" ]]; then
    mv "$cache_root" "${cache_root}.pre-dotfiles-${STAMP}"
  fi

  mkdir -p "$cache_root"
  rsync -a --delete "$plugin_root/" "$cache_root/"
  echo "installed local OMX plugin cache at $cache_root"
}

cleanup_stale_codex_skill_backups() {
  local stale_path

  shopt -s nullglob
  for stale_path in "$DOTFILES_DIR/.codex/skills"/*.pre-dotfiles-*; do
    [[ -e "$stale_path" || -L "$stale_path" ]] || continue
    rm -rf "$stale_path"
    echo "removed stale skill backup $stale_path"
  done
}

cleanup_legacy_gstack_skill_duplicates() {
  local skill_path
  local skill_name

  shopt -s nullglob
  for skill_path in "$DOTFILES_DIR/.codex/skills"/gstack-*; do
    [[ -d "$skill_path" ]] || continue
    [[ -f "$skill_path/SKILL.md" || -L "$skill_path/SKILL.md" ]] || continue

    skill_name="${skill_path##*/}"
    [[ "$skill_name" == "gstack-upgrade" ]] && continue

    rm -rf "$skill_path"
    echo "removed legacy gstack duplicate ${skill_path##*/}"
  done
}

install_local_omx_skills() {
  local skill_root="$HOME/.codex/plugins/cache/oh-my-codex-local/oh-my-codex/local/skills"
  local skill_path
  local skill_name

  if [[ ! -d "$skill_root" ]]; then
    echo "skip OMX skill mirror: missing skill root at $skill_root" >&2
    return
  fi

  mkdir -p "$DOTFILES_DIR/.codex/skills"

  shopt -s nullglob
  for skill_path in "$skill_root"/*; do
    [[ -d "$skill_path" ]] || continue
    [[ -f "$skill_path/SKILL.md" ]] || continue
    skill_name="${skill_path##*/}"
    link_path "$skill_path" "$DOTFILES_DIR/.codex/skills/$skill_name"
  done
}

install_gstack_checkout() {
  if [[ "${BOOTSTRAP_SKIP_GSTACK:-0}" == "1" ]]; then
    echo "skip gstack install/update: BOOTSTRAP_SKIP_GSTACK=1"
    return
  fi

  ensure_git_checkout "$GSTACK_REPO_URL" "$GSTACK_REPO_DIR" "main" "gstack"

  (
    cd "$GSTACK_REPO_DIR"
    if [[ -x ./setup ]]; then
      ./setup
      ./setup --host codex
    else
      bash ./setup
      bash ./setup --host codex
    fi
  )

  echo "gstack installed; not linking it into .agents/skills"
}

ensure_shared_skill_mirror() {
  mkdir -p "$DOTFILES_DIR/.codex/skills"

  local skill_name

  for skill_name in "${SHARED_SKILLS[@]}"; do
    [[ -d "$DOTFILES_DIR/.agents/skills/$skill_name" ]] || continue
    link_path "../../.agents/skills/$skill_name" "$DOTFILES_DIR/.codex/skills/$skill_name"
  done
}

ensure_claude_skill_links() {
  local skills_dir="$DOTFILES_DIR/.claude/skills"
  local skill_name

  mkdir -p "$DOTFILES_DIR/.claude"

  if [[ -L "$skills_dir" ]]; then
    rm -f "$skills_dir"
  elif [[ -e "$skills_dir" && ! -d "$skills_dir" ]]; then
    mv "$skills_dir" "${skills_dir}.pre-dotfiles-${STAMP}"
    echo "backed up $skills_dir -> ${skills_dir}.pre-dotfiles-${STAMP}"
  fi

  mkdir -p "$skills_dir"

  for skill_name in "${SHARED_SKILLS[@]}"; do
    [[ -d "$DOTFILES_DIR/.agents/skills/$skill_name" ]] || continue
    link_path "../../.agents/skills/$skill_name" "$skills_dir/$skill_name"
  done
}

cleanup_legacy_home_agent_skill_root() {
  local legacy_root="$HOME/.agents/skills"
  local archived_root="$HOME/.agents/skills.archived-omx-doctor-${STAMP}"

  if [[ ! -L "$legacy_root" ]]; then
    return
  fi

  mv "$legacy_root" "$archived_root"
  echo "archived legacy Codex skill root $legacy_root -> $archived_root"
}

repair_claude_links() {
  if [[ "$(readlink "$HOME/.claude" 2>/dev/null)" == "$DOTFILES_DIR/.claude" ]]; then
    echo "~/.claude already linked to $DOTFILES_DIR/.claude"
    ensure_claude_skill_links
    return
  fi

  mkdir -p "$HOME/.claude"
  ensure_claude_skill_links
  link_path "$DOTFILES_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  link_path "$DOTFILES_DIR/.claude/aliases.sh" "$HOME/.claude/aliases.sh"
  link_path "$DOTFILES_DIR/.claude/agents" "$HOME/.claude/agents"
  link_path "$DOTFILES_DIR/.claude/commands" "$HOME/.claude/commands"
  link_path "$DOTFILES_DIR/.claude/hooks" "$HOME/.claude/hooks"
  link_path "$DOTFILES_DIR/.claude/mcp.json" "$HOME/.claude/mcp.json"
  link_path "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
  link_path "$DOTFILES_DIR/.claude/skills" "$HOME/.claude/skills"
}

install_omx_from_fork
install_local_omx_plugin_cache
cleanup_stale_codex_skill_backups
install_local_omx_skills
cleanup_legacy_gstack_skill_duplicates

mkdir -p "$HOME/.agents" "$HOME/.codex"
mkdir -p "$DOTFILES_DIR/.codex/skills"
link_path "$DOTFILES_DIR/.codex/skills" "$HOME/.codex/skills"
# Keep the top-level Codex contract pointed at the repo copy so local setup
# refreshes do not leave behind a stale standalone file.
link_path "$DOTFILES_DIR/.codex/AGENTS.md" "$HOME/.codex/AGENTS.md"

cleanup_legacy_home_agent_skill_root
ensure_shared_skill_mirror
repair_claude_links
install_gstack_checkout

# Core shell files
link_path "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
link_path "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
link_path "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# Tmux config (new path first, legacy fallback)
TMUX_SRC="$DOTFILES_DIR/tmux/tmux.conf"
if [[ ! -f "$TMUX_SRC" && -f "$DOTFILES_DIR/.tmux.conf" ]]; then
  TMUX_SRC="$DOTFILES_DIR/.tmux.conf"
fi
if [[ -f "$TMUX_SRC" ]]; then
  link_path "$TMUX_SRC" "$HOME/.tmux.conf"
else
  echo "skip ~/.tmux.conf: no tmux config found in $DOTFILES_DIR" >&2
fi

# Git config (canonical in dotfiles when present)
if [[ -f "$DOTFILES_DIR/.gitconfig" ]]; then
  link_path "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
else
  echo "skip ~/.gitconfig: $DOTFILES_DIR/.gitconfig not found"
fi

# fzf shell setup tracked in dotfiles
if [[ -f "$DOTFILES_DIR/.fzf.zsh" ]]; then
  link_path "$DOTFILES_DIR/.fzf.zsh" "$HOME/.fzf.zsh"
fi

# Ensure fzf itself is installed and generate baseline if missing
if command -v fzf >/dev/null 2>&1; then
  if [[ ! -f "$DOTFILES_DIR/.fzf.zsh" ]] && [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    cp "$HOME/.fzf.zsh" "$DOTFILES_DIR/.fzf.zsh" || true
    link_path "$DOTFILES_DIR/.fzf.zsh" "$HOME/.fzf.zsh"
  fi
fi

# Spotlight exclusions for developer directories
if [[ "${BOOTSTRAP_SKIP_SPOTLIGHT:-0}" != "1" && "$(uname)" == "Darwin" ]]; then
  "$DOTFILES_DIR/scripts/spotlight-exclusions.sh" || echo "warning: spotlight exclusions failed" >&2
fi

echo "done"
