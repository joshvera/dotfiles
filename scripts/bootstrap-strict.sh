#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/github/dotfiles}"

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "dotfiles dir not found: $DOTFILES_DIR" >&2
  exit 1
fi

cd "$DOTFILES_DIR"

echo "[1/6] Install core packages"
brew bundle --file "$DOTFILES_DIR/Brewfile"

echo "[2/6] Install dev/bootstrap packages (includes Java 21)"
brew bundle --file "$DOTFILES_DIR/Brewfile.dev"

echo "[3/6] Sync submodules"
git submodule update --init --recursive

echo "[4/6] Link dotfiles"
"$DOTFILES_DIR/scripts/bootstrap-core.sh"

echo "[5/6] Strict preflight checks"
[[ -d "$DOTFILES_DIR/zsh/plugins/fzf-tab" ]] || { echo "missing plugin dir: zsh/plugins/fzf-tab" >&2; exit 1; }
[[ -f "$DOTFILES_DIR/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] || { echo "missing fzf-tab plugin file" >&2; exit 1; }

JAVA_HOME_21="$(/usr/libexec/java_home -v 21)" || { echo "JDK 21 not found after bootstrap" >&2; exit 1; }
[[ -n "$JAVA_HOME_21" ]] || { echo "JDK 21 path is empty" >&2; exit 1; }

echo "[6/6] Shell startup validation"
if ! zsh -i -c 'exit' >/tmp/bootstrap-strict-zsh.log 2>&1; then
  echo "zsh startup failed; tail follows:" >&2
  tail -n 120 /tmp/bootstrap-strict-zsh.log >&2
  exit 1
fi

if rg -n "plugin .* not found|Unable to locate a Java Runtime|command not found" /tmp/bootstrap-strict-zsh.log >/dev/null 2>&1; then
  echo "zsh startup produced strict-blocking warnings; tail follows:" >&2
  tail -n 120 /tmp/bootstrap-strict-zsh.log >&2
  exit 1
fi

echo "strict bootstrap OK"
