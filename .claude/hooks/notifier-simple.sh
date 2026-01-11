#!/usr/bin/env bash

# Simple notifier for Claude Code events
set -euo pipefail

# Debug logging
echo "$(date): Notification hook triggered with event: ${1:-none}" >> /tmp/claude-hook-debug.log

EVENT_TYPE="${1:-idle-notification}"

# Find config file
CONFIG_FILE=""
if [[ -f "$HOME/.claude/.config/claudetainer/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.claude/.config/claudetainer/ntfy.json"
elif [[ -f "$HOME/.config/claude-native/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.config/claude-native/ntfy.json"
fi

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Extract config
NTFY_TOPIC=$(jq -r '.ntfy_topic // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
NTFY_SERVER=$(jq -r '.ntfy_server // "https://ntfy.sh"' "$CONFIG_FILE" 2>/dev/null || echo "https://ntfy.sh")

if [[ -z "$NTFY_TOPIC" ]]; then
    exit 0
fi

# Simple context
CWD_BASENAME=$(basename "$(pwd)")
TITLE="Claude Code: $CWD_BASENAME"

case "$EVENT_TYPE" in
    "idle-notification")
        MESSAGE="Claude waiting for input"
        TAGS="claude-code,idle"
        ;;
    "notification")
        MESSAGE="Claude notification"
        TAGS="claude-code,notification"
        ;;
    "stop")
        MESSAGE="Claude finished responding"
        TAGS="claude-code,stop"
        ;;
    *)
        exit 0
        ;;
esac

# Send notification
curl -s --max-time 5 \
    -H "Title: $TITLE" \
    -H "Tags: $TAGS" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1 || true