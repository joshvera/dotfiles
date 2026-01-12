#!/usr/bin/env bash
# notification-handler.sh - Click-through handler for Claude Code notifications
# Usage: notification-handler.sh <json_payload> OR NOTIFICATION_PAYLOAD=<json> notification-handler.sh
#
# Exit Codes:
#   0 - Full success: Terminal focused, tmux navigated (if target provided), marker created
#   1 - Partial success: Marker created but some operations failed (terminal focus or tmux navigation)
#   2 - Complete failure: Critical error (malformed JSON, missing required fields, no marker created)

set -euo pipefail

DEBUG_LOG="/tmp/claude-hook-debug.log"

# Track operation success for exit code determination
MARKER_CREATED=false
TERMINAL_FOCUSED=false
TMUX_NAVIGATED=true  # Default to true (success if no tmux target provided)

log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [notification-handler] $1" >> "$DEBUG_LOG"
}

# Get payload from arg or env
PAYLOAD="${1:-${NOTIFICATION_PAYLOAD:-}}"
if [[ -z "$PAYLOAD" ]]; then
    log_debug "ERROR: No payload provided"
    exit 2
fi

log_debug "Received payload: $PAYLOAD"

# Parse JSON fields using jq
if ! command -v jq &>/dev/null; then
    log_debug "ERROR: jq not found (required for JSON parsing)"
    exit 2
fi

# Validate JSON is well-formed using jq -e (exits non-zero on parse error)
if ! echo "$PAYLOAD" | jq -e . >/dev/null 2>&1; then
    # Log first 100 chars of payload for debugging
    PAYLOAD_SNIPPET="${PAYLOAD:0:100}"
    log_debug "ERROR: Malformed JSON payload (first 100 chars): $PAYLOAD_SNIPPET"
    exit 2
fi

# Extract fields from JSON payload using jq -e for strict parsing
EVENT_ID=$(echo "$PAYLOAD" | jq -e -r '.event_id // empty' 2>/dev/null || echo "")
REPO_PATH=$(echo "$PAYLOAD" | jq -e -r '.repo_path // empty' 2>/dev/null || echo "")
TMUX_TARGET=$(echo "$PAYLOAD" | jq -e -r '.tmux_target // empty' 2>/dev/null || echo "")
TMUX_SESSION=$(echo "$PAYLOAD" | jq -e -r '.tmux_session // empty' 2>/dev/null || echo "")
CWD=$(echo "$PAYLOAD" | jq -e -r '.cwd // empty' 2>/dev/null || echo "")

log_debug "Parsed fields: event_id=$EVENT_ID, repo_path=$REPO_PATH, tmux_target=$TMUX_TARGET, tmux_session=$TMUX_SESSION, cwd=$CWD"

# Validate required fields are non-empty
if [[ -z "$EVENT_ID" ]]; then
    PAYLOAD_SNIPPET="${PAYLOAD:0:100}"
    log_debug "ERROR: Required field 'event_id' is missing or empty (first 100 chars): $PAYLOAD_SNIPPET"
    exit 2
fi

# Source shared session library for get_session_id()
SESSION_LIB="$HOME/.claude/hooks/lib/session.sh"
if [[ -f "$SESSION_LIB" ]]; then
    source "$SESSION_LIB"
else
    log_debug "ERROR: Session library not found: $SESSION_LIB"
    exit 2
fi

SESSION_ID=$(get_session_id)
STATE_DIR="/tmp/claude-notification-state-${SESSION_ID}"
CANCEL_MARKER="${STATE_DIR}/.cancel-${EVENT_ID}"

log_debug "Session ID: $SESSION_ID, State dir: $STATE_DIR"

# Create cancel marker (idempotent - user activity may have already created it)
if [[ -d "$STATE_DIR" ]]; then
    if touch "$CANCEL_MARKER" 2>/dev/null; then
        log_debug "Created cancel marker: $CANCEL_MARKER"
        MARKER_CREATED=true
    else
        log_debug "WARNING: Failed to create cancel marker (state dir may not exist)"
    fi
else
    log_debug "WARNING: State directory does not exist: $STATE_DIR"
fi

# Focus Ghostty terminal via AppleScript
log_debug "Focusing Ghostty terminal..."
if osascript -e 'tell application "Ghostty" to activate' >> "$DEBUG_LOG" 2>&1; then
    TERMINAL_FOCUSED=true
else
    log_debug "WARNING: Failed to focus Ghostty (may not be running or installed)"
    # Continue anyway - user might be using different terminal
fi

# Navigate to tmux pane if target is specified
if [[ -n "$TMUX_TARGET" ]]; then
    log_debug "Navigating to tmux pane: $TMUX_TARGET"
    TMUX_NAVIGATED=false  # Reset to false since we have a target to navigate to

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
                TMUX_NAVIGATED=true
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

# Determine exit code based on operation results
EXIT_CODE=0
STATUS="success"

if [[ "$MARKER_CREATED" == false ]]; then
    # Critical failure: marker not created
    EXIT_CODE=2
    STATUS="complete failure (no marker created)"
elif [[ "$TERMINAL_FOCUSED" == false ]] || [[ "$TMUX_NAVIGATED" == false ]]; then
    # Partial success: marker created but some operations failed
    EXIT_CODE=1
    STATUS="partial success (marker created, terminal_focused=$TERMINAL_FOCUSED, tmux_navigated=$TMUX_NAVIGATED)"
else
    # Full success: all operations succeeded
    STATUS="full success (terminal focused, tmux navigated, marker created)"
fi

log_debug "Notification handler complete for event: $EVENT_ID - Status: $STATUS (exit $EXIT_CODE)"
exit $EXIT_CODE
