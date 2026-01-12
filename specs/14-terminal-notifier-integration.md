# Spec: Terminal-Notifier Integration for Click Detection

## Purpose
Implement true desktop notification click detection using terminal-notifier, allowing users to explicitly dismiss desktop notifications which cancels the scheduled mobile backup. Builds on Spec 13 (reaction detection fix) to provide optional enhanced UX.

## Jobs to Be Done

### Job 1: Explicit Click Dismissal
When desktop notification is sent on macOS:
- Notification appears in Notification Center
- User sees it while at desk
- User wants to dismiss it AND prevent mobile notification
- Current outcome: User types in Claude (triggers on_user_activity), mobile cancels
- Better outcome: User clicks notification, mobile cancels immediately without needing to type

### Job 2: Use terminal-notifier If Available
- Many macOS users have terminal-notifier installed (via Homebrew)
- Falls back gracefully to osascript if not available
- No breaking changes if terminal-notifier not installed

### Job 3: Maintain Click Handler Simplicity
- Click handler is simple one-liner: create cancel marker
- No complex navigation or state tracking
- Works with or without click (user activity also cancels, as per Spec 13)

## Inputs
- Title and message (from mark_claude_finished/on_permission_request)
- Event ID (for cancel marker)
- Session ID (for state directory)

## Outputs
- Sent via terminal-notifier if available with execute handler
- Execute handler creates `.cancel-${event_id}` marker on click
- Falls back to osascript if terminal-notifier not available
- Mobile notification cancels when marker is created (from Spec 10 logic)

## Relationship to Spec 13

**Spec 13 (Reaction Detection Fix):** Moves cancellation from 2-second heuristic to real user activity (keystrokes)

**Spec 14 (This spec):** Adds OPTIONAL enhancement for click-based cancellation

**Combined behavior:**
- User clicks notification? Mobile cancels via click handler
- User types in Claude? Mobile cancels via on_user_activity()
- User does neither (AFK)? Mobile fires at 30s
- EITHER action cancels mobile (no double-cancellation)

## Detection Strategy

### Primary: terminal-notifier with Execute Handler
Use terminal-notifier's `-execute` flag to run command on click:

```bash
terminal-notifier \
    -title "Claude Code: project" \
    -message "Response ready" \
    -execute "touch /path/to/.cancel-${event_id}" \
    -sender "com.ghostty.terminal"
```

**Pros:**
- True click detection from notification daemon
- Works with macOS Notification Center
- Well-established command-line tool
- Many users already have it installed

**Cons:**
- Requires terminal-notifier package (not installed by default)
- Must be installed via Homebrew or other means

### Fallback: osascript + User Activity
If terminal-notifier not available:
- Send osascript notification (as before)
- Rely on on_user_activity() hook for cancellation
- User must type in Claude to cancel mobile
- No click-based cancellation (acceptable fallback)

### Why NOT JXA Click Tracking
- More complex than terminal-notifier
- Would duplicate terminal-notifier functionality
- terminal-notifier already proven and documented
- Harder to debug if click handler fails

## Dependencies
- terminal-notifier (OPTIONAL - `command -v terminal-notifier`)
- State directory from Spec 06
- Cancel marker pattern from Spec 10
- Spec 13 (reaction detection fix already implemented)

## Key Decisions

### Decision 1: Check Availability
Before sending notification, check if terminal-notifier is available:
```bash
if command -v terminal-notifier >/dev/null 2>&1; then
    # Use terminal-notifier with execute handler
else
    # Fall back to osascript
fi
```

### Decision 2: Simple Execute Handler
Click handler is minimal one-liner:
```bash
touch /path/to/.cancel-${event_id}
```
No complex shell logic, no error handling needed.

### Decision 3: Don't Require Click Handler Success
If `touch` fails in execute handler, notification was still displayed. Mobile timer checks marker at 30s, not finding it is acceptable outcome.

### Decision 4: Use Standard Sender
Use `-sender "com.ghostty.terminal"` for consistency with Ghostty terminal app. If user uses iTerm2 or Terminal.app, still works but sender may differ.

### Decision 5: Both Actions Cancel (Idempotent)
- Click creates cancel marker
- User activity (typing) ALSO creates cancel marker
- schedule_mobile_notification() checks marker once at 30s
- If marker exists (from either source), mobile doesn't fire
- No race conditions or double-notification issues

## Implementation

### Function: send_desktop_notification_with_click_handler()
New function replacing send_desktop_notification_with_reaction() when terminal-notifier available:

```bash
send_desktop_notification_with_click_handler() {
    local title="$1"
    local message="$2"
    local event_id="$3"

    if [[ -z "$title" || -z "$message" || -z "$event_id" ]]; then
        echo "$(date): send_desktop_notification_with_click_handler: missing required parameters" >> /tmp/claude-hook-debug.log
        return 1
    fi

    # Get state directory for cancel marker path
    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    local cancel_marker_path="${state_dir}/.cancel-${event_id}"

    # Try terminal-notifier with click handler
    if command -v terminal-notifier >/dev/null 2>&1; then
        # terminal-notifier execute handler: create cancel marker on click
        terminal-notifier \
            -title "$title" \
            -message "$message" \
            -execute "touch '$cancel_marker_path'" \
            -sender "com.ghostty.terminal" \
            2>/dev/null || {
            echo "$(date): terminal-notifier failed, falling back to osascript" >> /tmp/claude-hook-debug.log
            osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
        }
    else
        # Fallback: osascript without click handler
        echo "$(date): terminal-notifier not available, using osascript fallback" >> /tmp/claude-hook-debug.log
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi

    # Mark notification sent in metadata
    update_event_field "${event_id}" "desktop_notified" "true"

    echo "$(date): Desktop notification sent for event: $event_id (click handler enabled if terminal-notifier available)" >> /tmp/claude-hook-debug.log
}
```

### Integration in mark_claude_finished() and on_permission_request()
Replace calls to `send_desktop_notification_with_reaction()` with `send_desktop_notification_with_click_handler()`:

**In mark_claude_finished() (around line 877):**
```bash
# OLD:
send_desktop_notification_with_reaction "$title" "$summary" "$event_id"

# NEW:
send_desktop_notification_with_click_handler "$title" "$summary" "$event_id"
```

**In on_permission_request() (around line 947):**
```bash
# OLD:
send_desktop_notification_with_reaction "$title" "$message" "$event_id"

# NEW:
send_desktop_notification_with_click_handler "$title" "$message" "$event_id"
```

### Optional: Preserve Old Function for Compatibility
Keep `send_desktop_notification_with_reaction()` as alias:
```bash
send_desktop_notification_with_reaction() {
    send_desktop_notification_with_click_handler "$@"
}
```
This maintains backward compatibility if other scripts call the old function name.

## Verification

### Test 1: terminal-notifier Available
```bash
# Assume terminal-notifier is installed: brew install terminal-notifier

# Setup
session_id="test:main:%0"
event_id="test-click-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Initialize event metadata
record_event_metadata "$event_id" "stop" "Test message"

# Send notification with click handler
send_desktop_notification_with_click_handler "Claude Code: test" "Test message" "$event_id"

# Check that metadata was updated
cat "$state_dir/${event_id}.json" | jq '.desktop_notified'
# Expected: "true"

# Manually simulate click by creating cancel marker
touch "$state_dir/.cancel-${event_id}"

# Schedule mobile notification
schedule_mobile_notification "$event_id" "Test mobile"

# Wait 35 seconds - mobile should NOT fire (cancel marker exists)
sleep 35
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep "$event_id" && echo "FAIL: Mobile sent despite click" || echo "PASS: Click prevented mobile"
# Expected: PASS
```

### Test 2: terminal-notifier Not Available
```bash
# Temporarily hide terminal-notifier or test on system without it
# Update PATH or mock the command check

# Setup
session_id="test:main:%0"
event_id="test-osascript-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Initialize event metadata
record_event_metadata "$event_id" "stop" "Test message"

# Send notification (should fall back to osascript)
send_desktop_notification_with_click_handler "Claude Code: test" "Test message" "$event_id"

# Check debug log for fallback message
grep "osascript fallback\|terminal-notifier not available" /tmp/claude-hook-debug.log
# Expected: log entry showing fallback

# Check metadata updated
cat "$state_dir/${event_id}.json" | jq '.desktop_notified'
# Expected: "true"

# Verify on_user_activity() still cancels mobile (without click handler available)
schedule_mobile_notification "$event_id" "Test mobile"
on_user_activity
[[ -f "$state_dir/.cancel-${event_id}" ]] && echo "PASS: User activity created cancel marker"
# Expected: PASS
```

### Test 3: Click Handler Fails Gracefully
```bash
# Setup with bad cancel marker path (e.g., permission denied)
session_id="test:main:%0"
event_id="test-fail-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Create readonly state dir to force handler failure
chmod 444 "$state_dir"

# Initialize event metadata
record_event_metadata "$event_id" "stop" "Test message"

# Send notification - execute handler will fail
send_desktop_notification_with_click_handler "Claude Code: test" "Test message" "$event_id"

# Notification should still display (osascript doesn't fail)
# Function should return success (error is logged but non-fatal)

# Restore permissions
chmod 755 "$state_dir"
```

### Test 4: Multiple Concurrent Notifications with Clicks
```bash
# Setup
session_id="test:main:%0"
event_id1="test-concurrent-click-1-$(date +%s)"
event_id2="test-concurrent-click-2-$(date +%s)"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

# Initialize events
record_event_metadata "$event_id1" "stop" "Event 1"
record_event_metadata "$event_id2" "stop" "Event 2"

# Send both notifications
send_desktop_notification_with_click_handler "Claude Code: test" "Event 1" "$event_id1"
send_desktop_notification_with_click_handler "Claude Code: test" "Event 2" "$event_id2"

# Schedule both mobile notifications
schedule_mobile_notification "$event_id1" "Mobile 1"
schedule_mobile_notification "$event_id2" "Mobile 2"

# Simulate clicking first notification only
touch "$state_dir/.cancel-${event_id1}"

# Wait 35 seconds
sleep 35

# Check results
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep "$event_id1" && echo "FAIL: Event 1 sent (was clicked)" || echo "PASS: Event 1 cancelled by click"
grep "Sending mobile notification" /tmp/claude-hook-debug.log | grep "$event_id2" && echo "PASS: Event 2 sent (wasn't clicked)" || echo "FAIL: Event 2 cancelled"
# Expected: Event 1 cancelled, Event 2 sent
```

## Edge Cases

| Case | Handling |
|------|----------|
| terminal-notifier not installed | Falls back to osascript, user activity still cancels |
| Click handler command fails | Non-fatal, notification still sent, mobile still fires (acceptable) |
| User clicks but terminal-notifier exits early | Cancel marker may not be created, mobile fires (rare) |
| User both clicks AND types | Only one cancel marker created (idempotent, no issue) |
| Notification dismissed without clicking | schedule_mobile_notification() checks marker at 30s, not found, mobile fires |
| Execute handler path contains spaces | Must be properly quoted in command (handled by our implementation) |
| Special characters in title/message | Handled by terminal-notifier quoting (see Spec 15 for additional safety) |

## Compatibility & Installation

### User Installation
```bash
# macOS (Homebrew)
brew install terminal-notifier

# Or check existing installation
command -v terminal-notifier
```

### Fallback Behavior
If not installed, system still works perfectly:
- Notifications via osascript (macOS native)
- Cancellation via on_user_activity() hook
- User types to dismiss and prevent mobile backup
- No breaking changes, no error messages

## Testing Recommendation
Before rollout, test on:
- System WITH terminal-notifier installed
- System WITHOUT terminal-notifier installed
- Both cancellation paths (click + user activity)
- Multiple concurrent events

## Dependencies & Sequencing

- **Depends on:** Spec 13 (reaction detection fix)
- **Depends on:** Spec 10 (schedule_mobile_notification)
- **Depends on:** Spec 06 (state directory)
- **Optional enhancement to:** Spec 13
- **Pairs with:** Spec 15 (osascript string escaping)

## Implementation Location
Modify `~/.claude/hooks/idle-detector.sh`:
- Add new `send_desktop_notification_with_click_handler()` function
- Update `mark_claude_finished()` to call new function (line 877)
- Update `on_permission_request()` to call new function (line 947)
- Optional: Create alias `send_desktop_notification_with_reaction()` for backward compatibility

## Effort
**Short** - New function based on existing code, terminal-notifier is straightforward CLI tool, graceful fallback to existing osascript approach. ~40 lines of new code including error handling.

## Notes
- Test on multiple macOS versions to ensure terminal-notifier compatibility
- Verify sender ID works with Ghostty (may need to be verified/updated)
- Document installation step for users who want click-based dismissal
- Consider adding note to README about optional terminal-notifier dependency
