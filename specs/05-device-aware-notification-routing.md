# Spec: Device-Aware Notification Routing

## Purpose
Route notifications to appropriate channel (desktop or remote) based on device type and network environment, integrating with existing idle-detector.sh orchestrator.

## Inputs
- Event type: string ("notification", "stop", "idle-notification")
- Device detection signals:
  - `$SSH_CONNECTION`: Set when connected via SSH
  - `$MOSH_CONNECTION`: Set when connected via mosh
  - `CLAUDE_NOTIFY_MODE`: Optional environment override ("desktop" or "remote")
- Idle state information (transcript, permission context)
- All context from Spec 01-04 (tmux, payload, handlers)

## Outputs
- Notification sent via appropriate channel:
  - Desktop: `terminal-notifier` (Spec 03, via `notifier-desktop.sh`)
  - Remote: `ntfy` service (existing `notifier.sh`)
- Same JSON payload structure used for both channels

## Dependencies
- idle-detector.sh (orchestrator; existing)
- Spec 01: tmux-context-capture
- Spec 02: notification-payload-structure
- Spec 03: desktop-notification-sender (notifier-desktop.sh)
- Spec 04: notification-click-handler
- Existing: notifier.sh (ntfy sender)
- Bash 4.0+

## Device Detection Logic

```
1. If CLAUDE_NOTIFY_MODE explicitly set:
   - Use "desktop" or "remote" as specified
   - Rationale: Allows manual override for testing/special cases

2. Else if $SSH_CONNECTION or $MOSH_CONNECTION set:
   - Device type = "remote"
   - Rationale: SSH/mosh indicate remote session; can't use terminal-notifier

3. Else (local terminal):
   - Device type = "desktop"
   - Rationale: Local macOS session; use native notifications

4. If device type = "desktop":
   - Source notifier-desktop.sh
   - Call function to send terminal-notifier notification

5. Else (remote):
   - Source existing notifier.sh
   - Call function to send ntfy notification
```

## Key Decisions

### Decision 1: Environment Override
Allow `CLAUDE_NOTIFY_MODE=desktop|remote` to override detection. Rationale: Supports testing and edge cases (e.g., local SSH tunneling).

### Decision 2: Payload Consistency
Use identical JSON payload structure for both channels (Spec 02). Desktop handler consumes payload; remote ntfy includes payload in notification body or separate metadata. Rationale: Single source of truth for notification data.

### Decision 3: Backward Compatibility
Existing `notifier.sh` (ntfy) behavior unchanged; only add routing logic and optional desktop path. Rationale: Maintains existing mobile/remote notifications while adding desktop support.

### Decision 4: Failure Recovery
If desktop notifier fails (e.g., terminal-notifier not installed), fall back to ntfy. Rationale: Ensures some notification always sent; user not left hanging.

## Integration with idle-detector.sh

Modify idle-detector.sh to:
1. Detect device type early (add `detect_device_type()` function if not exists)
2. Capture tmux context (Spec 01) before calling notifier
3. Build JSON payload (Spec 02)
4. Call appropriate notifier based on device type:
   ```bash
   if [ "$DEVICE_TYPE" = "desktop" ]; then
       source "$HOOKS_DIR/notifier-desktop.sh"
       send_desktop_notification "$TITLE" "$MESSAGE" "$PAYLOAD"
   else
       source "$HOOKS_DIR/notifier.sh"
       send_ntfy_notification "$TITLE" "$MESSAGE" "$PAYLOAD"
   fi
   ```

## Verification
```bash
# Test 1: Local desktop detection
unset SSH_CONNECTION MOSH_CONNECTION
bash -c 'source idle-detector.sh; detect_device_type; echo $DEVICE_TYPE'
# Expected: "desktop"

# Test 2: SSH remote detection
SSH_CONNECTION="192.168.1.10 22 192.168.1.1 22" bash -c 'source idle-detector.sh; detect_device_type; echo $DEVICE_TYPE'
# Expected: "remote"

# Test 3: Manual override to desktop
CLAUDE_NOTIFY_MODE=desktop SSH_CONNECTION="..." bash -c 'source idle-detector.sh; detect_device_type; echo $DEVICE_TYPE'
# Expected: "desktop"

# Test 4: End-to-end notification on desktop
# Trigger idle timeout in local tmux session
# Expected: Notification appears in Notification Center, click navigates to Ghostty

# Test 5: Existing ntfy flow still works
# Trigger notification from remote SSH session
# Expected: ntfy notification sent to service (existing behavior)
```

## Implementation Location
Modify `~/.claude/hooks/idle-detector.sh`:
- Add/enhance `detect_device_type()` function
- Call context capture (Spec 01) before notifier
- Build JSON payload (Spec 02)
- Add conditional routing to notifier-desktop.sh or notifier.sh
- Fallback to ntfy if desktop send fails

Create new file `~/.claude/hooks/notifier-desktop.sh`:
- Function wrapper around terminal-notifier call
- Accept title, message, payload arguments
- Handle missing terminal-notifier gracefully
