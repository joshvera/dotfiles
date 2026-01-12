#!/usr/bin/env bash
# Shared session identification library for Claude Code notification hooks
# Source this file to get access to get_session_id()

# Generate a unique session ID for state isolation
#
# Format: hostname:session:pane_id (or hostname:shell:hash as fallback)
# Returns: session ID string suitable for state directory naming
#
# UNIQUENESS ASSUMPTIONS AND TRADE-OFFS:
#
# This function generates session IDs in the format "hostname:session:pane" which
# provides sufficient uniqueness for typical usage patterns:
#
# 1. **Tmux environments**: hostname + session name + pane ID is unique within a
#    single host. Multiple tmux sessions with the same name on different hosts are
#    distinguished by hostname. Multiple panes in the same session are distinguished
#    by pane ID.
#
# 2. **Non-tmux environments**: Falls back to hostname + hash of terminal device
#    and PID. This is unique at creation time but may not be stable across shell
#    restarts.
#
# 3. **Why not include PID in all cases?**
#    Adding PID to the session ID would break state persistence when shells restart
#    within the same tmux pane. The current design intentionally preserves state
#    across shell restarts, which is the desired behavior for long-running tmux
#    sessions where you may restart your shell but want to maintain notification
#    state and event history.
#
# 4. **Collision scenarios** (edge cases):
#    - **Containerized systems**: Multiple containers on the same host with identical
#      session names could collide if hostname is the same. If running in containers,
#      consider setting unique hostnames or session names.
#    - **Hostname conflicts**: Multiple machines with identical hostnames on the same
#      shared filesystem (e.g., NFS home directory) could collide. This is rare and
#      indicates a misconfigured network.
#    - **Session name reuse**: Destroying and recreating a tmux session with the same
#      name will reuse state from the previous session. This is intentional (preserves
#      history) but may surprise users expecting fresh state.
#
# 5. **Current design decision**: The hostname:session:pane format is "good enough"
#    for typical single-user, single-host scenarios where tmux is the primary terminal
#    multiplexer. The trade-off prioritizes state persistence over perfect collision
#    avoidance in edge cases.
#
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
