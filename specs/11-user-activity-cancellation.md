# Spec: User Activity Cancellation

## Purpose
Cancel all pending mobile notifications when the user submits input to Claude (UserPromptSubmit hook), indicating they are actively using the session and don't need notifications.

## Inputs
- Session ID (from Spec 04)
- State directory with active timers
- UserPromptSubmit hook trigger

## Outputs
- All pending timer processes killed
- Cancel markers created for all active events
- Permission context file cleared

## Cancellation Flow
```
UserPromptSubmit Hook
    │
    ├──► Get session ID
    ├──► For each timer in timers/*.timer:
    │    ├── Read PID from file
    │    ├── Kill process (SIGTERM)
    │    ├── Create .cancel-${event_id} marker
    │    └── Remove timer file
    │
    ├──► Clear permission context file
    └──► Clear idle state file
```

## Dependencies
- Session ID function from Spec 04
- Timer files from Spec 08
- State directory structure

## Key Decisions

### Decision 1: Kill All Timers
Kill ALL pending timers for the session, not just the most recent. User activity indicates engagement with the session; no mobile notifications needed.

### Decision 2: Create Cancel Markers
Create cancel markers even after killing timers. Belt-and-suspenders: if timer process doesn't die immediately, it will see the marker.

### Decision 3: Graceful Kill
Use basic `kill` (SIGTERM) not `kill -9`. Allow timer process to clean up if possible.

### Decision 4: Ignore Kill Failures
Timer process may have already exited. Ignore kill failures silently.

### Decision 5: Full State Reset
Also clear idle state file and permission context file. User is active; previous pending notifications are obsolete.

## Implementation

```bash
on_user_activity() {
    local session_id
    session_id=$(get_session_id)

    local state_dir="/tmp/claude-notification-state-${session_id}"

    # Clear legacy state files
    rm -f "$IDLE_STATE_FILE" 2>/dev/null || true
    rm -f "$PERMISSION_CONTEXT_FILE" 2>/dev/null || true

    # Kill all pending timers and create cancel markers
    if [[ -d "$state_dir/timers" ]]; then
        for timer_file in "$state_dir/timers"/*.timer 2>/dev/null; do
            [[ ! -f "$timer_file" ]] && continue

            local pid event_id
            event_id=$(basename "$timer_file" .timer)
            pid=$(cat "$timer_file" 2>/dev/null)

            # Kill background process
            if [[ -n "$pid" ]]; then
                kill "$pid" 2>/dev/null || true
            fi

            # Create cancel marker (belt-and-suspenders)
            touch "$state_dir/.cancel-${event_id}" 2>/dev/null || true

            # Remove timer file
            rm -f "$timer_file"

            echo "$(date): Cancelled timer for event_id=$event_id (user activity)" \
                >> /tmp/claude-hook-debug.log
        done
    fi

    # Also kill legacy idle detector if running
    if [[ -f "$IDLE_DETECTOR_PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$IDLE_DETECTOR_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]]; then
            kill "$old_pid" 2>/dev/null || true
        fi
        rm -f "$IDLE_DETECTOR_PID_FILE"
    fi
}
```

## Hook Handler Integration

```bash
# In case statement for script arguments
"user-activity")
    on_user_activity
    ;;
```

## settings.json Configuration (existing)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/idle-detector.sh user-activity"
          }
        ]
      }
    ]
  }
}
```

## Verification
```bash
# Setup: Create a pending timer
session_id="test:main:%0"
event_id="test-cancel-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Start a long-running background process to simulate timer
(sleep 300) &
timer_pid=$!
echo "$timer_pid" > "$state_dir/timers/${event_id}.timer"

# Verify timer is running
ps -p "$timer_pid" && echo "Timer running"
# Expected: Timer running

# Simulate user activity
on_user_activity

# Verify timer killed
ps -p "$timer_pid" 2>/dev/null && echo "Still running" || echo "Killed"
# Expected: Killed

# Verify cancel marker created
[[ -f "$state_dir/.cancel-${event_id}" ]] && echo "Cancel marker exists"
# Expected: Cancel marker exists

# Verify timer file removed
[[ ! -f "$state_dir/timers/${event_id}.timer" ]] && echo "Timer file removed"
# Expected: Timer file removed
```

## Edge Cases

| Case | Handling |
|------|----------|
| No pending timers | Function completes silently |
| Timer already exited | Kill fails silently, cancel marker still created |
| Multiple timers | All killed and cancelled |
| State directory missing | Function completes silently |
| Timer file unreadable | Skip to next timer |

## Implementation Location
Modify `~/.claude/hooks/idle-detector.sh`:
- Replace existing `stop_idle_monitor()` logic in "user-activity" case
- Add new `on_user_activity()` function
