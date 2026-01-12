# Spec: Hook Orchestration

## Purpose
Coordinate the notification system components across Stop and PermissionRequest hooks, ensuring proper event lifecycle: ID generation, metadata recording, desktop notification, and mobile scheduling.

## Inputs
- Hook type: "Stop" | "PermissionRequest"
- Hook stdin: JSON with `transcript_path` (Stop) or `tool_name` (PermissionRequest)
- Environment: tmux/Zellij session info, working directory

## Outputs
- Immediate desktop notification (osascript)
- Scheduled mobile notification (30s delayed ntfy)
- Event metadata recorded in state directory
- Proper cleanup of previous pending notifications

## Hook Flow

### Stop Hook (`mark_claude_finished`)
```
Stop Hook Fires
    │
    ├──► Read hook input (transcript_path)
    ├──► Generate session_id, event_id
    ├──► Initialize state directory
    ├──► Kill any existing timers (prevents duplicate notifications)
    │
    ├──► Generate summary:
    │    ├── Read last response from transcript
    │    └── Summarize with Haiku (or fallback)
    │
    ├──► Record event metadata
    ├──► Send desktop notification with reaction detection
    └──► Schedule mobile notification (30s)
```

### PermissionRequest Hook (`on_permission_request`)
```
PermissionRequest Hook Fires
    │
    ├──► Read hook input (tool_name)
    ├──► Generate session_id, event_id
    ├──► Initialize state directory
    ├──► Kill any existing timers
    │
    ├──► Generate context-aware summary:
    │    └── Based on tool_name (AskUserQuestion, Edit, Bash, etc.)
    │
    ├──► Record event metadata
    ├──► Send desktop notification with reaction detection
    └──► Schedule mobile notification (30s)
```

## Dependencies
- All previous specs (04-09)
- Claude Code hooks configuration in settings.json

## Key Decisions

### Decision 1: Timer Cleanup on New Event
Kill existing timers before scheduling new ones. Prevents notification spam when Stop→PermissionRequest fire in rapid succession.

### Decision 2: Unified Flow
Both hooks follow the same pattern: generate IDs, record metadata, desktop notify, schedule mobile. Only the summary generation differs.

### Decision 3: Non-Blocking
All operations must be non-blocking. Desktop notification returns immediately; mobile timer runs in background. Hook must not delay Claude's operation.

### Decision 4: Stdin Consumption
Read stdin once at hook start, parse for relevant fields. Hook input is consumed; cannot be re-read later.

## Implementation

### Stop Hook Handler
```bash
mark_claude_finished() {
    local session_id event_id state_dir

    # Generate identifiers
    session_id=$(get_session_id)
    event_id=$(generate_event_id)
    state_dir=$(initialize_state_dir "$session_id")

    # Read hook input
    local hook_input=""
    if [[ ! -t 0 ]]; then
        hook_input=$(cat)
    fi

    local transcript_path
    transcript_path=$(echo "$hook_input" | jq -r '.transcript_path // empty' 2>/dev/null)

    echo "$(date): Stop hook - session=$session_id event=$event_id transcript=${transcript_path:-none}" \
        >> /tmp/claude-hook-debug.log

    # Kill existing timers for this session
    kill_pending_timers "$session_id"

    # Generate summary from transcript
    local summary=""
    if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
        local response
        response=$(get_last_response "$transcript_path")
        if [[ -n "$response" ]]; then
            summary=$(summarize_with_haiku "$response")
        fi
    fi
    summary="${summary:-Response ready}"

    # Record event metadata
    record_event_metadata "$session_id" "$event_id" "Stop" "$summary"

    # Desktop notification (immediate)
    send_desktop_notification_with_reaction "$session_id" "$event_id" "$summary"

    # Mobile notification (30s delayed)
    schedule_mobile_notification "$session_id" "$event_id" "$summary"
}
```

### PermissionRequest Hook Handler
```bash
on_permission_request() {
    local session_id event_id state_dir

    # Generate identifiers
    session_id=$(get_session_id)
    event_id=$(generate_event_id)
    state_dir=$(initialize_state_dir "$session_id")

    # Read hook input
    local hook_input=""
    if [[ ! -t 0 ]]; then
        hook_input=$(cat)
    fi

    local tool_name
    tool_name=$(echo "$hook_input" | jq -r '.tool_name // "unknown"' 2>/dev/null)

    echo "$(date): PermissionRequest hook - session=$session_id event=$event_id tool=$tool_name" \
        >> /tmp/claude-hook-debug.log

    # Kill existing timers
    kill_pending_timers "$session_id"

    # Generate context-aware summary
    local summary
    summary=$(get_permission_summary "$tool_name")

    # Record event metadata
    record_event_metadata "$session_id" "$event_id" "PermissionRequest" "$summary"

    # Desktop notification (immediate)
    send_desktop_notification_with_reaction "$session_id" "$event_id" "$summary"

    # Mobile notification (30s delayed)
    schedule_mobile_notification "$session_id" "$event_id" "$summary"
}
```

### Timer Cleanup Helper
```bash
kill_pending_timers() {
    local session_id="$1"
    local state_dir="/tmp/claude-notification-state-${session_id}"

    if [[ ! -d "$state_dir/timers" ]]; then
        return 0
    fi

    for timer_file in "$state_dir/timers"/*.timer 2>/dev/null; do
        [[ ! -f "$timer_file" ]] && continue

        local pid
        pid=$(cat "$timer_file" 2>/dev/null)
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
        rm -f "$timer_file"
    done
}
```

### Case Statement
```bash
case "${1:-}" in
    "claude-finished")
        mark_claude_finished
        ;;
    "permission-request")
        on_permission_request
        ;;
    "user-activity")
        on_user_activity
        ;;
    # ... other cases
esac
```

## settings.json Configuration
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/idle-detector.sh claude-finished"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/idle-detector.sh permission-request"
          }
        ]
      }
    ],
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
# Test Stop hook
echo '{"transcript_path":"/tmp/test-transcript.jsonl"}' | \
    ~/.claude/hooks/idle-detector.sh claude-finished
# Check: Desktop notification appears, timer scheduled

# Test PermissionRequest hook
echo '{"tool_name":"AskUserQuestion"}' | \
    ~/.claude/hooks/idle-detector.sh permission-request
# Check: Desktop notification with "Waiting for your answer"

# Test rapid succession
echo '{"transcript_path":"..."}' | ~/.claude/hooks/idle-detector.sh claude-finished
sleep 1
echo '{"tool_name":"Edit"}' | ~/.claude/hooks/idle-detector.sh permission-request
# Check: Only one timer active (first killed)

# Check debug log
tail -20 /tmp/claude-hook-debug.log
```

## Implementation Location
Modify `~/.claude/hooks/idle-detector.sh`:
- Refactor `mark_claude_finished()` to use new infrastructure
- Add `on_permission_request()` function
- Add `kill_pending_timers()` helper
- Update case statement
