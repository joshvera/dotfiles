# Spec: Mobile Notification Scheduler

## Purpose
Schedule delayed mobile notifications (30 seconds) via ntfy, with cancellation logic that checks for desktop reaction markers before sending.

## Inputs
- Session ID (from Spec 04)
- Event ID (from Spec 05)
- Summary text (from Spec 06)
- State directory path
- `NTFY_URL` and `NTFY_TOPIC` environment variables

## Outputs
- Background timer process (PID stored in `timers/${event_id}.timer`)
- ntfy notification sent after 30s delay (if not cancelled)
- Updated `mobile_sent: true` in metadata.json
- Cleanup of timer and cancel marker files

## Timer Lifecycle
```
schedule_mobile_notification()
    │
    ├──► Create timer PID file
    ├──► Fork background process
    │    ├── Sleep 30 seconds
    │    ├── Check .cancel-${event_id} marker
    │    │   ├── If exists → skip ntfy, log cancellation
    │    │   └── If not exists → send ntfy
    │    ├── Update metadata (mobile_sent)
    │    └── Cleanup timer file
    │
    └──► Return immediately (non-blocking)
```

## Dependencies
- `curl` for ntfy API
- `NTFY_URL` environment variable (from secrets)
- `NTFY_TOPIC` environment variable (default: "wintermute")
- State directory and cancel markers from Specs 04, 07

## Key Decisions

### Decision 1: Delay Duration
Use 30-second delay. Rationale: Long enough that user likely noticed desktop notification if present; short enough to be useful for away-from-desk scenarios.

### Decision 2: Timer Storage
Store background process PID in `timers/${event_id}.timer`. Enables explicit killing on UserPromptSubmit (Spec 09).

### Decision 3: Full Detachment
Use `setsid` (Linux) or `nohup` (macOS) with closed stdio. Timer must survive parent process exit.

### Decision 4: Cancel Check Timing
Check cancel marker immediately before sending ntfy, not at start of timer. Allows desktop reaction to happen during the 30s window.

### Decision 5: Cleanup Responsibility
Timer process cleans up its own files (timer PID file, cancel marker) after completion. Prevents file accumulation.

## Implementation

```bash
schedule_mobile_notification() {
    local session_id="$1"
    local event_id="$2"
    local summary="${3:-Response ready}"

    local state_dir="/tmp/claude-notification-state-${session_id}"
    local cancel_file="$state_dir/.cancel-${event_id}"
    local timer_file="$state_dir/timers/${event_id}.timer"

    # Fork fully detached background timer
    (
        # Detach stdio
        exec </dev/null >/dev/null 2>&1

        sleep 30

        # Check cancellation before sending
        if [[ -f "$cancel_file" ]]; then
            echo "$(date): Mobile notification cancelled (event_id=$event_id)" \
                >> /tmp/claude-hook-debug.log
            rm -f "$cancel_file" "$timer_file"
            return 0
        fi

        # Verify state directory still exists (session may have ended)
        if [[ ! -d "$state_dir" ]]; then
            return 0
        fi

        # Check if event was superseded by newer event
        local metadata_file="$state_dir/metadata.json"
        if [[ -f "$metadata_file" ]]; then
            local current_event_id superseded
            current_event_id=$(jq -r '.event_id // empty' "$metadata_file" 2>/dev/null)
            superseded=$(jq -r '.superseded // false' "$metadata_file" 2>/dev/null)

            if [[ "$current_event_id" != "$event_id" || "$superseded" == "true" ]]; then
                echo "$(date): Mobile notification skipped (superseded, event_id=$event_id)" \
                    >> /tmp/claude-hook-debug.log
                rm -f "$timer_file"
                return 0
            fi
        fi

        # Send ntfy notification
        send_idle_notification "$summary"

        # Update metadata
        if [[ -f "$metadata_file" ]]; then
            jq '.mobile_sent = true' "$metadata_file" > "${metadata_file}.tmp" 2>/dev/null
            mv "${metadata_file}.tmp" "$metadata_file" 2>/dev/null || true
        fi

        # Cleanup
        rm -f "$cancel_file" "$timer_file"

        echo "$(date): Mobile notification sent (event_id=$event_id)" \
            >> /tmp/claude-hook-debug.log
    ) &

    local worker_pid=$!
    echo "$worker_pid" > "$timer_file"
    disown "$worker_pid" 2>/dev/null || true
}
```

## ntfy Notification Function (existing)

```bash
send_idle_notification() {
    local summary="${1:-}"
    local ntfy_url="${NTFY_URL:-}"
    local ntfy_topic="${NTFY_TOPIC:-wintermute}"

    if [[ -z "$ntfy_url" ]]; then
        return 0
    fi

    local cwd_basename
    cwd_basename=$(basename "$PWD")
    local title="Claude Code: $cwd_basename"

    # Add session info
    local session_info=""
    if [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        session_info=" → $(hostname):${ZELLIJ_SESSION_NAME}"
    elif [[ -n "${TMUX:-}" ]]; then
        local tmux_session
        tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "tmux")
        session_info=" → $(hostname):${tmux_session}"
    fi

    local message="${summary:-Waiting for input}${session_info}"

    curl -s --max-time 5 \
        -H "Title: $title" \
        -H "Tags: claude-code,idle" \
        -d "$message" \
        "$ntfy_url/$ntfy_topic" > /dev/null 2>&1 || true
}
```

## Verification
```bash
# Test mobile scheduling (fast timeout for testing)
# Temporarily modify IDLE_TIMEOUT or sleep duration

session_id="test:main:%0"
event_id="test-mobile-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Initialize metadata
record_event_metadata "$session_id" "$event_id" "Stop" "Test summary"

# Schedule notification (use shorter delay for testing)
schedule_mobile_notification "$session_id" "$event_id" "Test mobile notification"

# Check timer file created
cat "$state_dir/timers/${event_id}.timer"
# Expected: PID number

# Test cancellation
touch "$state_dir/.cancel-${event_id}"
# Wait for timer to complete - should NOT send notification
# Check logs: grep "cancelled" /tmp/claude-hook-debug.log
```

## Implementation Location
Add to `~/.claude/hooks/idle-detector.sh`:
- `schedule_mobile_notification()` - main scheduler function
- Modify existing `send_idle_notification()` if needed
