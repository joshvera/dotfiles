#!/usr/bin/env bash
# Inject .codex/developer-instructions.md into ~/.codex/config.toml as
# `developer_instructions`. config.toml stays untracked (it holds machine
# paths and tool-written state), so only this managed block is ours.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/github/dotfiles}"
SRC="$DOTFILES_DIR/.codex/developer-instructions.md"
CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
BEGIN="# BEGIN dotfiles developer_instructions (generated from .codex/developer-instructions.md; edit that file)"
END="# END dotfiles developer_instructions"

die() {
  echo "sync-codex-developer-instructions: $*" >&2
  exit 1
}

[[ -f "$SRC" ]] || die "missing $SRC"
# The block is a TOML multi-line literal string, which cannot contain '''.
if grep -q "'''" "$SRC"; then
  die "$SRC contains ''' and cannot be embedded as a TOML literal string"
fi

mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"

# Everything in config.toml except a previous copy of our block.
rest="$(awk -v b="$BEGIN" -v e="$END" '
  $0 == b { skip = 1; next }
  $0 == e { skip = 0; next }
  !skip
' "$CONFIG")"

if grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' <<<"$rest"; then
  die "$CONFIG already sets developer_instructions outside the managed block; remove it first"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  # Top-level keys must precede any [table], so the block goes first.
  printf '%s\n' "$BEGIN"
  printf "developer_instructions = '''\n"
  cat "$SRC"
  printf "'''\n"
  printf '%s\n' "$END"
  [[ -n "$rest" ]] && printf '%s\n' "$rest"
} >"$tmp"

# Write through rather than mv, so a symlinked config.toml keeps its link.
cat "$tmp" >"$CONFIG"
echo "synced developer_instructions into $CONFIG"
