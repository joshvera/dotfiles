#!/bin/bash
# Force zellij layout refresh by killing and restarting session
# Usage: refresh-layout.sh [session-name]
# NOTE: Run this from OUTSIDE zellij

if [[ -n "$ZELLIJ" ]]; then
    echo "Error: This script must be run from outside zellij"
    echo "Exit zellij first, then run: $0"
    exit 1
fi

# Get session name from argument or find running session
if [[ -n "$1" ]]; then
    SESSION_NAME="$1"
else
    SESSION_NAME=$(zellij list-sessions 2>/dev/null | grep RUNNING | head -1 | awk '{print $1}')
fi

if [[ -z "$SESSION_NAME" ]]; then
    echo "No active zellij session found"
    echo "Usage: $0 [session-name]"
    exit 1
fi

echo "Refreshing zellij session: $SESSION_NAME"
zellij kill-session "$SESSION_NAME" 2>/dev/null
sleep 0.2
exec zellij attach "$SESSION_NAME" 2>/dev/null || exec zellij -s "$SESSION_NAME"