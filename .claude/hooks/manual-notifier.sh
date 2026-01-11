#!/usr/bin/env bash

# Manual notification trigger for testing
set -euo pipefail

# Find config file
CONFIG_FILE=""
if [[ -f "$HOME/.claude/.config/claudetainer/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.claude/.config/claudetainer/ntfy.json"
elif [[ -f "$HOME/.config/claude-native/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.config/claude-native/ntfy.json"
fi

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "No ntfy config found"
    exit 1
fi

# Extract config
NTFY_TOPIC=$(jq -r '.ntfy_topic // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
NTFY_SERVER=$(jq -r '.ntfy_server // "https://ntfy.sh"' "$CONFIG_FILE" 2>/dev/null || echo "https://ntfy.sh")

if [[ -z "$NTFY_TOPIC" ]]; then
    echo "No ntfy topic configured"
    exit 1
fi

# Simple context
CWD_BASENAME=$(basename "$(pwd)")
TITLE="Claude Code: $CWD_BASENAME (Manual Test)"
MESSAGE="Manual notification test from SSH/Zellij session"
TAGS="claude-code,test,manual"

# Send notification
echo "Sending notification to: $NTFY_TOPIC"
curl -s --max-time 5 \
    -H "Title: $TITLE" \
    -H "Tags: $TAGS" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" && echo " - Success!" || echo " - Failed!"