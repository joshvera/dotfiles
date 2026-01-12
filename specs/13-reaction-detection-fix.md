# Spec: Reaction Detection Fix

## Purpose
Fix critical flaw in reaction detection that unconditionally cancels mobile notifications after a 2-second delay, defeating the mobile backup when user is AFK. Replace heuristic delay with real user activity detection.

## Jobs to Be Done

### Job 1: Prevent False Mobile Cancellations
When desktop notification is sent and user is NOT at keyboard:
- Desktop notification appears but user ignores it
- After 2 seconds, current system creates cancel marker (WRONG)
- Mobile notification fails to send at 30s mark (BAD OUTCOME)
- Expected outcome: Mobile notification should fire, user can respond from mobile

### Job 2: Still Cancel Mobile on Real User Activity
When desktop notification is sent and user IS at keyboard:
- Desktop notification appears
- User responds by typing in Claude session
- UserPromptSubmit hook fires, marking user activity
- Mobile notification cancels immediately (GOOD OUTCOME)
- User sees notification dismissed on mobile too

### Job 3: Maintain Backward Compatibility
- Existing `on_user_activity()` hook already exists and works
- Simply wire it up to create cancel markers instead of fake 2s delay
- No new dependencies, no terminal-notifier required (that's optional in spec 14)

## Inputs
- Event ID (from Spec 07)
- Session ID (from Spec 06)
- State directory path

## Outputs
- `.cancel-${event_id}` marker file ONLY created on real user activity (UserPromptSubmit hook)
- `flags.desktop_reacted: true` in metadata.json ONLY on real user activity
- Desktop notification no longer self-cancels after 2s

## Problem Statement

### Current Implementation (BROKEN)
```bash
send_desktop_notification_with_reaction() {
    # ... send notification ...
    (
        sleep 2  # <-- UNCONDITIONAL 2-SECOND DELAY
        touch "$cancel_file"  # <-- Creates cancel marker
        update_event_field "desktop_reacted" "true"  # <-- Marks as reacted
    ) &
    disown
}
```

**Issue:** This assumes user ALWAYS sees and reacts to notification within 2 seconds, regardless of device. If user is AFK (on mobile), notification is silently cancelled and mobile backup never fires.

### Desired Implementation
1. Desktop notification sent without implicit cancel delay
2. `on_user_activity()` hook creates cancel markers when user actually types
3. If user never types before 30s, mobile notification fires (CORRECT)
4. If user types before 30s, mobile cancels (ALSO CORRECT)

## Detection Strategy

### Strategy: Real User Activity (Recommended, Implemented in Spec 11)
Leverage existing `on_user_activity()` function that fires on UserPromptSubmit hook:
- Called when user submits input to Claude session
- Already kills pending timers
- Already creates cancel markers
- Already clears idle state

**Why it works:**
- Typing in terminal = genuine user activity
- No false positives (delay-based guessing)
- No false negatives (real activity always captured)
- No macOS API dependencies
- Already fully implemented in Spec 11

### Why NOT 2-Second Heuristic
- Assumes all users see notification within 2s
- Ignores use case: user debugging code, not watching screen
- Ignores mobile use case: user away from desk on phone
- Defeats purpose of dual-channel notification system
- Kills mobile backup unconditionally

### Why NOT terminal-notifier Click Handler (Alternative in Spec 14)
- That's a separate optional enhancement for explicit click detection
- This spec fixes the fundamental design flaw
- Keystroke-based detection is sufficient and simpler

## Dependencies
- `on_user_activity()` function from Spec 11 (already implemented)
- UserPromptSubmit hook configuration (already in settings.json)
- State directory from Spec 06
- Cancel marker pattern from Spec 10

## Key Decisions

### Decision 1: Remove 2-Second Sleep
Delete the `sleep 2` line from `send_desktop_notification_with_reaction()`. Desktop notification sends immediately without background delay process.

### Decision 2: Let UserPromptSubmit Hook Handle Cancellation
Rely on existing hook orchestration (Spec 12) to call `on_user_activity()` when user types. That function already:
- Kills pending timers
- Creates cancel markers
- Updates metadata
- Clears legacy state

### Decision 3: No Changes to send_desktop_notification_with_reaction()
Except removing the implicit sleep/cancel logic. Function becomes simpler:
- Send osascript notification
- Update metadata.desktop_notified field
- Return immediately (no background process for cancellation)

### Decision 4: Rely on Schedule_mobile_notification() Checks
The mobile timer already checks for cancel markers (Spec 10):
```bash
if [[ -f "$cancel_marker" ]]; then
    # Don't send mobile notification
fi
```
No changes needed there. Cancel markers only created by real user activity now.

## Implementation

### Phase 1: Simplify send_desktop_notification_with_reaction()
Remove the implicit cancel logic:

```bash
send_desktop_notification_with_reaction() {
    local title="$1"
    local message="$2"
    local event_id="$3"

    if [[ -z "$title" || -z "$message" || -z "$event_id" ]]; then
        echo "$(date): send_desktop_notification_with_reaction: missing required parameters" >> /tmp/claude-hook-debug.log
        return 1
    fi

    # Send immediate desktop notification (NO BACKGROUND PROCESS)
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true

    # Mark notification sent in metadata
    local state_dir
    state_dir=$(initialize_state_dir) || return 1
    update_event_field "${event_id}" "desktop_notified" "true"

    echo "$(date): Desktop notification sent for event: $event_id (no implicit cancellation)" >> /tmp/claude-hook-debug.log
}
```

**Key changes:**
- Removed `(sleep 2; touch "$cancel_file") & disown` block
- No more background process for 2-second delay
- Only sends notification and updates metadata
- Cancel markers only created by real user activity

### Phase 2: Verify on_user_activity() Wiring
Confirm UserPromptSubmit hook calls on_user_activity():

In `~/.claude/settings.json`:
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

This calls `on_user_activity()` which:
- Kills pending mobile notification timers
- Creates cancel markers for all active events
- Clears legacy state files

**No changes needed** - wiring already correct.

## Verification

### Test 1: Desktop notification sends immediately
```bash
# Setup
session_id="test:main:%0"
event_id="test-event-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Initialize event metadata
record_event_metadata "$event_id" "stop" "Test message"

# Send desktop notification
send_desktop_notification_with_reaction "Claude Code: test" "Test message" "$event_id"

# Check metadata
cat "$state_dir/${event_id}.json" | jq '.desktop_notified'
# Expected: "true"

# Check for cancel marker immediately (should NOT exist)
ls "$state_dir/.cancel-${event_id}" 2>/dev/null && echo "FAIL: Cancel marker exists" || echo "PASS: No cancel marker yet"
# Expected: PASS (no cancel marker yet)

# Wait 2 seconds (old behavior would create marker here)
sleep 2

# Check again - still no cancel marker
ls "$state_dir/.cancel-${event_id}" 2>/dev/null && echo "FAIL: Cancel marker exists" || echo "PASS: Still no cancel marker"
# Expected: PASS (no cancel marker after 2s either)
```

### Test 2: Mobile notification fires when no user activity
```bash
# Setup from Test 1, with mobile timer scheduled
schedule_mobile_notification "$event_id" "Test mobile message"

# Wait 35 seconds (mobile timer delay is 30s)
# Check that ntfy was called (see /tmp/claude-hook-debug.log)
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep "$event_id"
# Expected: log entry showing mobile notification was sent

# Verify timer file cleaned up
[[ ! -f "$state_dir/timers/${event_id}.timer" ]] && echo "PASS: Timer cleaned up" || echo "FAIL: Timer still exists"
# Expected: PASS
```

### Test 3: User activity cancels mobile
```bash
# Setup
event_id="test-activity-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
record_event_metadata "$event_id" "stop" "Test message"
send_desktop_notification_with_reaction "Claude Code: test" "Test" "$event_id"
schedule_mobile_notification "$event_id" "Test mobile"

# Verify timer is running
[[ -f "$state_dir/timers/${event_id}.timer" ]] && echo "PASS: Timer scheduled"
# Expected: PASS

# Simulate user activity (call the hook handler)
on_user_activity

# Check that cancel marker was created
[[ -f "$state_dir/.cancel-${event_id}" ]] && echo "PASS: Cancel marker created" || echo "FAIL: No cancel marker"
# Expected: PASS

# Check that timer file was removed
[[ ! -f "$state_dir/timers/${event_id}.timer" ]] && echo "PASS: Timer cleaned up" || echo "FAIL: Timer still exists"
# Expected: PASS

# Wait to confirm mobile notification is NOT sent
sleep 35
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep "$event_id" || echo "PASS: Mobile notification was cancelled"
# Expected: PASS (no mobile notification log entry)
```

### Test 4: Multiple concurrent events
```bash
# Setup two concurrent events
event_id1="test-concurrent-1-$(date +%s)"
event_id2="test-concurrent-2-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"

record_event_metadata "$event_id1" "stop" "Event 1"
record_event_metadata "$event_id2" "stop" "Event 2"

send_desktop_notification_with_reaction "Claude Code: test" "Event 1" "$event_id1"
send_desktop_notification_with_reaction "Claude Code: test" "Event 2" "$event_id2"

schedule_mobile_notification "$event_id1" "Mobile 1"
schedule_mobile_notification "$event_id2" "Mobile 2"

# Verify both timers scheduled
[[ -f "$state_dir/timers/${event_id1}.timer" ]] && echo "PASS: Event 1 timer scheduled"
[[ -f "$state_dir/timers/${event_id2}.timer" ]] && echo "PASS: Event 2 timer scheduled"

# Simulate user activity
on_user_activity

# Verify both cancelled
[[ -f "$state_dir/.cancel-${event_id1}" ]] && echo "PASS: Event 1 cancelled"
[[ -f "$state_dir/.cancel-${event_id2}" ]] && echo "PASS: Event 2 cancelled"

# Wait and verify neither sends mobile notification
sleep 35
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep -E "(${event_id1}|${event_id2})" && echo "FAIL: Mobile was sent" || echo "PASS: Both cancelled"
# Expected: PASS
```

## Edge Cases

| Case | Handling |
|------|----------|
| User types immediately after notification | on_user_activity() creates cancel marker immediately, mobile never fires |
| User never types (AFK 30s+) | Mobile notification fires at 30s mark (CORRECT) |
| User types after 20s | Mobile cancels immediately (CORRECT) |
| Multiple rapid desktop responses | Each creates event, on_user_activity() cancels all pending |
| No UserPromptSubmit hook | Mobile notifications fire at 30s (safe fallback) |
| State directory missing | on_user_activity() handles gracefully, no errors |
| Permission request while mobile timer pending | mark_events_superseded() cancels via superseded flag |

## Dependencies & Sequencing

- **Depends on:** Spec 11 (on_user_activity() already implemented)
- **Depends on:** Spec 10 (schedule_mobile_notification() already implemented)
- **Depends on:** Spec 06 (state directory management)
- **Enables:** Spec 14 (terminal-notifier integration as optional enhancement)
- **Pairs with:** Spec 15 (osascript string escaping)

## Implementation Location
Modify `~/.claude/hooks/idle-detector.sh`:
- `send_desktop_notification_with_reaction()` function (lines 612-641)
  - Remove the `(sleep 2; touch ...) & disown` block
  - Keep notification send and metadata update
- Verify `on_user_activity()` function (lines 959-1008) has cancel marker creation
- Verify UserPromptSubmit hook in `settings.json` calls `idle-detector.sh user-activity`

## Effort
**Quick** - Simplification of existing code, no new functionality added. Remove ~10 lines of incorrect logic, leverage existing infrastructure already in place.
