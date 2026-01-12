#!/usr/bin/env bash
# Shared session identification library for Claude Code notification hooks
# Source this file to get access to get_session_id()

# Generate a unique session ID for state isolation
# Format: hostname:session:pane_id (or hostname:shell:hash as fallback)
# Returns: session ID string suitable for state directory naming
get_session_id() {
    local hostname
    hostname=$(hostname -s)

    # Tmux: use session name and pane ID for pane-level isolation
    if [[ -n "${TMUX:-}" ]]; then
        local session pane_id
        session=$(tmux display-message -p '#S' 2>/dev/null || echo "tmux")
        pane_id=$(tmux display-message -p '#D' 2>/dev/null || echo "0")
        # Remove leading % from pane_id if present
        pane_id="${pane_id#%}"
        echo "${hostname}:${session}:${pane_id}"
        return
    fi

    # Zellij: use session name (Zellij doesn't expose pane ID as easily)
    if [[ -n "${ZELLIJ:-}" || -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        local session="${ZELLIJ_SESSION_NAME:-zellij}"
        echo "${hostname}:${session}:0"
        return
    fi

    # Fallback: hash of terminal device and PID for uniqueness
    local term_device="${TTY:-notty}"
    local hash
    hash=$(echo "${hostname}:${term_device}:$$" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$$")
    echo "${hostname}:shell:${hash:0:8}"
}
