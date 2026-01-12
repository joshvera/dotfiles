#!/usr/bin/env bash
#
# notify.sh - Hook to send notifications on task completion via ntfy
#
# This hook is triggered on_task_complete to send push notifications
# when a task is successfully completed.
#
# Configuration:
#   Requires ~/.config/claude-native/ntfy.json with:
#     {"ntfy_topic": "your-topic-name", "ntfy_server": "https://ntfy.sh"}
#
# Environment Variables (provided by wiggum):
#   WIGGUM_EVENT        - Event type (on_task_complete)
#   WIGGUM_TASK_ID      - Task number/identifier
#   WIGGUM_TASK_TITLE   - Task description/title
#   WIGGUM_COMMIT_SHA   - Git commit hash for this task
#   WIGGUM_PROJECT_ROOT - Project root directory path
#
# Exit Codes:
#   0 - Success (or notification not configured)
#   1 - Notification delivery failed
#

set -euo pipefail

# Extract task information from environment
TASK_ID="${WIGGUM_TASK_ID:-unknown}"
TASK_TITLE="${WIGGUM_TASK_TITLE:-No title}"
COMMIT_SHA="${WIGGUM_COMMIT_SHA:-unknown}"
PROJECT_ROOT="${WIGGUM_PROJECT_ROOT:-.}"

# Get project name from directory
PROJECT_NAME=$(basename "$PROJECT_ROOT" 2>/dev/null || echo "unknown")

# Find config file
CONFIG_FILE=""
if [[ -f "$HOME/.config/claude-native/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.config/claude-native/ntfy.json"
elif [[ -f "$HOME/.config/claudetainer/ntfy.json" ]]; then
    CONFIG_FILE="$HOME/.config/claudetainer/ntfy.json"
fi

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "WARNING: ntfy config not found - skipping notification" >&2
    echo "Create ~/.config/claude-native/ntfy.json with:" >&2
    echo '  {"ntfy_topic": "your-topic", "ntfy_server": "https://ntfy.sh"}' >&2
    exit 0
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq not found, cannot parse ntfy config" >&2
    exit 0
fi

# Extract config
NTFY_TOPIC=$(jq -r '.ntfy_topic // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
NTFY_SERVER=$(jq -r '.ntfy_server // "https://ntfy.sh"' "$CONFIG_FILE" 2>/dev/null || echo "https://ntfy.sh")

if [[ -z "$NTFY_TOPIC" ]]; then
    echo "WARNING: ntfy_topic not configured" >&2
    exit 0
fi

# Truncate commit SHA to short form
COMMIT_SHORT="${COMMIT_SHA:0:7}"

# Build notification
TITLE="Task Complete: $PROJECT_NAME"
MESSAGE="Task $TASK_ID: $TASK_TITLE"
[[ "$COMMIT_SHORT" != "unknown" ]] && MESSAGE="$MESSAGE ($COMMIT_SHORT)"

# Send notification
echo "Sending ntfy notification..." >&2

if curl -s --max-time 5 \
    -H "Title: $TITLE" \
    -H "Tags: wiggum,task-complete,checkmark" \
    -H "Priority: default" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1; then
    echo "Notification sent successfully" >&2
    exit 0
else
    echo "WARNING: Failed to send notification" >&2
    exit 0  # Don't block on notification failure
fi
