# Spec: Session State Management

## Purpose
Generate unique session identifiers and manage per-session state directories to enable isolation between multiple Claude Code instances running in different tmux panes, Zellij sessions, or terminal windows.

## Inputs
- Environment variables: `$TMUX`, `$ZELLIJ_SESSION_NAME`, `$SSH_CONNECTION`
- Current working directory (`$PWD`)
- Hostname (via `hostname` command)

## Outputs
- `SESSION_ID`: Unique session identifier string
- `STATE_DIR`: Path to session-specific state directory
- State directory structure:
  ```
  /tmp/claude-notification-state-${SESSION_ID}/
  ├── metadata.json        # Current event metadata
  ├── .cancel-${event_id}  # Desktop reaction markers
  └── timers/
      └── ${event_id}.timer  # Background timer PIDs
  ```

## Session ID Format

| Priority | Environment | Format | Example |
|----------|-------------|--------|---------|
| 1 | tmux | `hostname:session:pane_id` | `mac:main:%5` |
| 2 | Zellij | `hostname:session_name:0` | `mac:dev:0` |
| 3 | SSH/other | `hostname:md5(cwd)[0:8]` | `mac:a3f8c2d1` |
| 4 | Local fallback | `local:md5(cwd)[0:8]` | `local:b7e4f9a2` |

## Dependencies
- `tmux` command (optional, for tmux detection)
- `hostname` command
- `md5sum` or `md5` command (for fallback hash)
- Bash 4.0+

## Key Decisions

### Decision 1: Pane-Level Isolation
Use tmux pane ID (not just session) to isolate parallel Claude instances in different panes of the same session. Each pane gets its own state directory.

### Decision 2: State Directory Location
Use `/tmp/` for state files. These are ephemeral and should not persist across reboots. Cleanup via `find -mtime +7`.

### Decision 3: Safe Path Characters
Session IDs may contain colons and percent signs. These are valid in Unix filenames but should be sanitized if needed for other uses.

### Decision 4: Directory Creation
Create state directory lazily on first event, not at script initialization. Avoids creating directories for sessions that never trigger notifications.

## Implementation

```bash
get_session_id() {
    local session_id

    if [[ -n "${TMUX:-}" ]]; then
        local host session pane
        host=$(hostname -s 2>/dev/null || hostname)
        session=$(tmux display-message -p '#S' 2>/dev/null) || session="tmux"
        pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || pane="%0"
        session_id="${host}:${session}:${pane}"

    elif [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        local host
        host=$(hostname -s 2>/dev/null || hostname)
        session_id="${host}:${ZELLIJ_SESSION_NAME}:0"

    else
        local host cwd_hash
        host=$(hostname -s 2>/dev/null || hostname)
        if command -v md5sum >/dev/null 2>&1; then
            cwd_hash=$(echo -n "$PWD" | md5sum | cut -c1-8)
        else
            cwd_hash=$(echo -n "$PWD" | md5 | cut -c1-8)
        fi
        if [[ -n "${SSH_CONNECTION:-}" ]]; then
            session_id="${host}:${cwd_hash}"
        else
            session_id="local:${cwd_hash}"
        fi
    fi

    echo "$session_id"
}

initialize_state_dir() {
    local session_id="$1"
    local state_dir="/tmp/claude-notification-state-${session_id}"
    mkdir -p "$state_dir/timers"
    echo "$state_dir"
}
```

## Verification
```bash
# Test in tmux
tmux new-session -d -s test
tmux send-keys -t test "source idle-detector.sh && get_session_id" Enter
# Expected: hostname:test:%0

# Test outside tmux
unset TMUX ZELLIJ_SESSION_NAME
cd /tmp/test-dir
source idle-detector.sh && get_session_id
# Expected: local:a3f8c2d1 (hash of /tmp/test-dir)

# Verify state directory creation
state_dir=$(initialize_state_dir "$(get_session_id)")
ls -la "$state_dir"
# Expected: directory with timers/ subdirectory
```

## Implementation Location
Add functions to `~/.claude/hooks/idle-detector.sh`:
- `get_session_id()` - session ID resolution
- `initialize_state_dir()` - state directory creation
