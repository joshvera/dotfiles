#!/usr/bin/env bash
# notification-handler.sh - Click-through handler for Claude Code notifications
# Usage: notification-handler.sh <json_payload> OR NOTIFICATION_PAYLOAD=<json> notification-handler.sh

set -euo pipefail

DEBUG_LOG="/tmp/claude-hook-debug.log"

log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [notification-handler] $1" >> "$DEBUG_LOG"
}

# Get payload from arg or env
PAYLOAD="${1:-${NOTIFICATION_PAYLOAD:-}}"
if [[ -z "$PAYLOAD" ]]; then
    log_debug "ERROR: No payload provided"
    exit 1
fi

log_debug "Received payload: $PAYLOAD"

# Parse JSON fields using jq
if ! command -v jq &>/dev/null; then
    log_debug "ERROR: jq not found (required for JSON parsing)"
    exit 1
fi

# Extract fields from JSON payload
EVENT_ID=$(echo "$PAYLOAD" | jq -r '.event_id // empty' 2>/dev/null || echo "")
REPO_PATH=$(echo "$PAYLOAD" | jq -r '.repo_path // empty' 2>/dev/null || echo "")
TMUX_TARGET=$(echo "$PAYLOAD" | jq -r '.tmux_target // empty' 2>/dev/null || echo "")
TMUX_SESSION=$(echo "$PAYLOAD" | jq -r '.tmux_session // empty' 2>/dev/null || echo "")
CWD=$(echo "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null || echo "")

log_debug "Parsed fields: event_id=$EVENT_ID, repo_path=$REPO_PATH, tmux_target=$TMUX_TARGET, tmux_session=$TMUX_SESSION, cwd=$CWD"

# Validate required fields
if [[ -z "$EVENT_ID" ]]; then
    log_debug "ERROR: event_id missing from payload"
    exit 1
fi

# Source shared session library for get_session_id()
SESSION_LIB="$HOME/.claude/hooks/lib/session.sh"
if [[ -f "$SESSION_LIB" ]]; then
    source "$SESSION_LIB"
else
    log_debug "ERROR: Session library not found: $SESSION_LIB"
    exit 1
fi

SESSION_ID=$(get_session_id)
STATE_DIR="/tmp/claude-notification-state-${SESSION_ID}"
CANCEL_MARKER="${STATE_DIR}/.cancel-${EVENT_ID}"

log_debug "Session ID: $SESSION_ID, State dir: $STATE_DIR"

# Create cancel marker (idempotent - user activity may have already created it)
if [[ -d "$STATE_DIR" ]]; then
    touch "$CANCEL_MARKER" 2>/dev/null && {
        log_debug "Created cancel marker: $CANCEL_MARKER"
    } || {
        log_debug "WARNING: Failed to create cancel marker (state dir may not exist)"
    }
else
    log_debug "WARNING: State directory does not exist: $STATE_DIR"
fi

# Focus Ghostty terminal via AppleScript
log_debug "Focusing Ghostty terminal..."
if ! osascript -e 'tell application "Ghostty" to activate' >> "$DEBUG_LOG" 2>&1; then
    log_debug "WARNING: Failed to focus Ghostty (may not be running or installed)"
    # Continue anyway - user might be using different terminal
fi

# Navigate to tmux pane if target is specified
if [[ -n "$TMUX_TARGET" ]]; then
    log_debug "Navigating to tmux pane: $TMUX_TARGET"

    # Parse TMUX_TARGET format: SESSION:WINDOW.PANE
    session=$(echo "$TMUX_TARGET" | cut -d: -f1)
    window=$(echo "$TMUX_TARGET" | cut -d: -f2 | cut -d. -f1)
    pane=$(echo "$TMUX_TARGET" | cut -d. -f2)

    log_debug "Parsed tmux target: session=$session, window=$window, pane=$pane"

    # Check if tmux is available
    if ! command -v tmux &>/dev/null; then
        log_debug "WARNING: tmux not found"
    else
        # Try to select the window and pane
        if tmux select-window -t "${session}:${window}" >> "$DEBUG_LOG" 2>&1; then
            log_debug "Selected window: ${session}:${window}"

            # Then select the pane
            if tmux select-pane -t "$TMUX_TARGET" >> "$DEBUG_LOG" 2>&1; then
                log_debug "Selected pane: $TMUX_TARGET"
            else
                log_debug "WARNING: Failed to select pane: $TMUX_TARGET (may need to recover session)"

                # Try to recover by attaching to session
                log_debug "Attempting to attach to session: $session"
                # Note: We can't actually attach here since we're in a detached context
                # This is a limitation - the user would need to manually attach
            fi
        else
            log_debug "WARNING: Failed to select window: ${session}:${window}"
        fi
    fi
else
    log_debug "No tmux target specified, skipping tmux navigation"
fi

log_debug "Notification handler complete for event: $EVENT_ID"
