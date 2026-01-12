# Spec: Desktop Reaction Detection

## Purpose
Detect when a user has "reacted to" a desktop notification, creating a cancellation marker that prevents the delayed mobile notification from firing.

## Inputs
- Event ID (from Spec 05)
- Session ID (from Spec 04)
- State directory path

## Outputs
- `.cancel-${event_id}` marker file in state directory
- Updated `desktop_reacted: true` in metadata.json

## Detection Strategy

### Primary: Heuristic Delay (Recommended)
After sending desktop notification, wait 2 seconds then create cancel marker. Assumes: if user is at desktop, they saw the notification within 2 seconds.

**Rationale:**
- Simple, reliable, no macOS API dependencies
- Low false-negative rate (user at desktop almost always sees notification)
- Acceptable false-positive rate (if user away, mobile fires anyway at 30s)
- No notification click handler required

### Alternative: JXA Click Tracking (Complex)
Use JavaScript for Automation (JXA) with NSUserNotificationCenter to detect actual notification clicks.

**Pros:** True reaction detection
**Cons:** Complex, requires terminal-notifier or custom notification app, may not work with newer macOS notification system (UserNotifications framework)

## Dependencies
- State directory from Spec 04
- Background process capability (fork + disown)

## Key Decisions

### Decision 1: Heuristic Delay Duration
Use 2-second delay. Rationale: Long enough for notification to appear and be noticed, short enough to not significantly impact mobile cancellation logic.

### Decision 2: Cancel Marker Format
Create empty file `.cancel-${event_id}` rather than updating metadata.json. Rationale: File existence check is atomic and fast; avoids JSON parsing in mobile timer.

### Decision 3: Background Execution
Run delay + marker creation in background subprocess. Desktop notification function returns immediately; marker created asynchronously.

### Decision 4: Multiple Events
Each event gets its own cancel marker. Multiple events can coexist; mobile timer checks its specific event_id's marker.

## Implementation

```bash
send_desktop_notification_with_reaction() {
    local session_id="$1"
    local event_id="$2"
    local summary="${3:-Response ready}"

    local state_dir="/tmp/claude-notification-state-${session_id}"
    local cancel_file="$state_dir/.cancel-${event_id}"
    local title="Claude Code: $(basename "$PWD")"

    # Send osascript notification immediately
    osascript -e "display notification \"$summary\" with title \"$title\"" 2>/dev/null || true

    # Mark desktop_notified in metadata
    update_event_field "$session_id" "desktop_notified" "true"

    # Schedule cancel marker after 2s delay (background)
    (
        sleep 2
        touch "$cancel_file"
        update_event_field "$session_id" "desktop_reacted" "true"
        echo "$(date): Desktop reaction marker created for event_id=$event_id" >> /tmp/claude-hook-debug.log
    ) &
    disown
}
```

## Alternative: terminal-notifier with Click Handler

If click detection is required, use terminal-notifier with execute handler:

```bash
send_desktop_notification_with_click_handler() {
    local session_id="$1"
    local event_id="$2"
    local summary="${3:-Response ready}"

    local state_dir="/tmp/claude-notification-state-${session_id}"
    local cancel_file="$state_dir/.cancel-${event_id}"
    local title="Claude Code: $(basename "$PWD")"

    # Click handler script creates cancel marker
    local handler_cmd="touch '$cancel_file'"

    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier \
            -title "$title" \
            -subtitle "Claude Code" \
            -message "$summary" \
            -execute "$handler_cmd" \
            -sender "com.ghostty.terminal" \
            2>/dev/null || true
    else
        # Fallback to osascript + heuristic
        osascript -e "display notification \"$summary\" with title \"$title\"" 2>/dev/null || true
        (sleep 2; touch "$cancel_file") &
        disown
    fi

    update_event_field "$session_id" "desktop_notified" "true"
}
```

## Verification
```bash
# Test heuristic reaction detection
session_id="test:main:%0"
event_id="test-event-123"
state_dir="/tmp/claude-notification-state-${session_id}"
mkdir -p "$state_dir/timers"

send_desktop_notification_with_reaction "$session_id" "$event_id" "Test message"

# Check immediately - no cancel file
ls "$state_dir/.cancel-${event_id}" 2>/dev/null && echo "EXISTS" || echo "NOT YET"
# Expected: NOT YET

# Wait 3 seconds
sleep 3
ls "$state_dir/.cancel-${event_id}" 2>/dev/null && echo "EXISTS" || echo "NOT YET"
# Expected: EXISTS

# Check metadata
cat "$state_dir/metadata.json" | jq '.desktop_reacted'
# Expected: true
```

## Implementation Location
Add/modify in `~/.claude/hooks/idle-detector.sh`:
- `send_desktop_notification_with_reaction()` - replaces simple `send_desktop_notification()`
- Integrates with `update_event_field()` from Spec 05
