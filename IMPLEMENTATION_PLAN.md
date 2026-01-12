# Implementation Plan

## Overview
Build a dual-channel notification system for Claude Code that sends immediate desktop notifications (via osascript) and delayed mobile notifications (via ntfy), with intelligent cancellation when the user reacts at the desktop within 30 seconds.

## Current State
The existing `idle-detector.sh` has foundational infrastructure:
- Device detection (desktop/mobile via SSH/mosh detection) - **COMPLETE**
- Haiku summarization via API - **COMPLETE**
- Basic desktop notification (osascript) - **COMPLETE**
- ntfy notification sending - **COMPLETE**
- Basic idle monitoring with background process - **COMPLETE** (but needs refactoring)
- Permission context handling (inline in notify-with-summary) - **PARTIAL**

## Tasks

### 1. Session State Infrastructure
- **Priority**: high
- **Status**: complete
- **Description**: Implement session ID generation and state directory management. Add `get_session_id()` function with tmux pane-level isolation (format: `hostname:session:pane_id`), Zellij support, and fallback hash. Create `initialize_state_dir()` to set up `/tmp/claude-notification-state-${SESSION_ID}/timers/` structure.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Running `get_session_id` in tmux returns `hostname:session:%N` format; state directory created with timers/ subdirectory
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `get_session_id()` with tmux pane ID (#D format), Zellij session name, and fallback hash
  - Implemented `initialize_state_dir()` creating `/tmp/claude-notification-state-${SESSION_ID}/timers/`
  - Added test commands: `test-session-id` and `test-state-dir`
  - Verified working in tmux with session ID format: `hostname:session:pane_id`

### 2. Event ID and Metadata System
- **Priority**: high
- **Status**: complete
- **Description**: Add event lifecycle management. Implement `generate_event_id()` (UUID4 via uuidgen with fallback), `record_event_metadata()` (JSON with event_id, event_type, timestamp, session_id, summary, flags), and `update_event_field()` for atomic updates. Mark previous events as superseded when new events arrive.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Metadata JSON created in state directory; fields update atomically; supersession tracking works
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `generate_event_id()` using uuidgen with fallback to timestamp+random
  - Implemented `record_event_metadata()` creating JSON with all required fields (event_id, event_type, timestamp, session_id, summary, flags)
  - Implemented `update_event_field()` with atomic updates using jq and temp files
  - Supports both top-level fields and nested flags.* fields with proper boolean conversion
  - Implemented `mark_events_superseded()` to mark all previous events in session as superseded
  - Added test commands: `test-event-id` and `test-metadata` (comprehensive test of all functions)
  - All tests pass successfully with proper JSON structure and atomic updates

### 3. Permission Summary Function
- **Priority**: medium
- **Status**: complete
- **Description**: Extract permission summary logic into standalone `get_permission_summary()` function. Already partially implemented inline in `notify-with-summary` case - refactor to reusable function. Map AskUserQuestion → "Waiting for your answer", Edit/Write/MultiEdit → "Waiting for permission: File edit", Bash/BashOutput → "Waiting for permission: Run command", others → "Waiting for permission: {tool_name}".
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Each tool type returns appropriate human-readable summary; existing functionality preserved
- **Completed**: 2026-01-11
- **Notes**:
  - Extracted `get_permission_summary()` function that takes tool_name as parameter
  - Maps AskUserQuestion → "Waiting for your answer"
  - Maps Edit/Write/MultiEdit → "Waiting for permission: File edit"
  - Maps Bash/BashOutput → "Waiting for permission: Run command"
  - Maps all other tools → "Waiting for permission: {tool_name}"
  - Refactored `notify-with-summary` case to use new function (reduced 15 lines to 2)
  - Added `test-permission-summary` test command for validation
  - All tests pass: AskUserQuestion, Edit, Write, MultiEdit, Bash, BashOutput, WebFetch work correctly
  - Existing functionality fully preserved - integration tests confirm workflow still works

### 4. tmux Context Capture
- **Priority**: medium
- **Status**: complete
- **Description**: Capture tmux session, window, and pane identifiers at notification time for optional click-through functionality. Set `TMUX_SESSION`, `TMUX_WINDOW`, `TMUX_PANE`, `TMUX_TARGET` variables. Handle non-tmux environments gracefully (set to empty).
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Variables populated correctly in tmux; empty outside tmux; format `SESSION:WINDOW.PANE`
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `capture_tmux_context()` function that captures tmux session, window, and pane identifiers
  - Checks for `$TMUX` environment variable to detect tmux environment
  - In tmux: captures session name (#S), window index (#I), and pane index (#P) using `tmux display-message -p`
  - Builds combined `TMUX_TARGET` in format `SESSION:WINDOW.PANE` (e.g., "clawd:1.1")
  - Outside tmux: gracefully sets all variables to empty strings
  - All variables exported for use by other functions
  - Added comprehensive test command `test-tmux-context` that validates:
    - Variable capture inside tmux (session, window, pane, target format)
    - Format validation using regex pattern (SESSION:WINDOW.PANE)
    - Component consistency (TMUX_TARGET matches individual components)
    - Graceful handling outside tmux (all variables empty)
    - Export verification (variables visible in subshells)
  - All tests pass successfully in both tmux and non-tmux environments
  - Debug logging shows captured context for troubleshooting
  - Function ready for integration into notification payload builder (Task 5)

### 5. Notification Payload Builder
- **Priority**: medium
- **Status**: complete
- **Description**: Create `build_notification_payload()` function to build standardized JSON payload with: event_type, repo_path (git root detection), cwd, tmux_target, tmux_session, transcript_path, permission_context, timestamp (ISO 8601). Validate with jq before use.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Valid JSON payload generated; repo_path correctly finds .git parent; all fields present
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `build_notification_payload()` function that takes event_type, message, and optional tool_name as parameters
  - Detects git repo root via `git rev-parse --show-toplevel` (empty string if not in git repo)
  - Captures current working directory via `pwd`
  - Calls `capture_tmux_context()` to populate tmux_target and tmux_session variables
  - Reads transcript_path from `CLAUDE_TRANSCRIPT_PATH` environment variable (empty if not set)
  - Generates ISO 8601 timestamp using `date -u +"%Y-%m-%dT%H:%M:%SZ"`
  - Builds JSON payload using jq with proper escaping for all fields
  - Validates JSON is valid before returning (double validation for safety)
  - Returns validated JSON payload to stdout
  - Added comprehensive test command `test-notification-payload` that validates:
    - Basic payload construction with all required fields (Test 1)
    - Permission request payload with tool_name/permission_context (Test 2)
    - Error handling for missing parameters (Test 3)
    - JSON validity via jq
    - ISO 8601 timestamp format validation
    - Git repo detection (correct path inside repo, empty outside)
    - tmux context integration (populated in tmux, empty outside)
  - All tests pass successfully in tmux environment inside git repo
  - Gracefully handles missing values (empty strings instead of null)
  - Ready for integration into notification handlers (Tasks 14-15 for click-through)

### 6. Desktop Notification with Reaction Detection
- **Priority**: high
- **Status**: complete
- **Description**: Create `send_desktop_notification_with_reaction()` function that sends osascript notification immediately, then spawns background process that waits 2 seconds and creates `.cancel-${event_id}` marker and updates metadata `desktop_reacted: true`. This replaces the simple `send_desktop_notification()` for the new architecture.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Desktop notification appears; cancel marker created after 2s delay; metadata updated
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `send_desktop_notification_with_reaction()` function that takes title, message, and event_id as parameters
  - Sends immediate macOS desktop notification via osascript
  - Spawns fully detached background process using `( ... ) &>/dev/null & disown` pattern
  - Background process waits 2 seconds, then creates `.cancel-${event_id}` marker file
  - Background process updates event metadata with `desktop_reacted: true` flag via `update_event_field()`
  - Added comprehensive test command `test-desktop-reaction` that validates:
    - Desktop notification is sent (visible on macOS)
    - Cancel marker is created after 2s delay
    - Metadata is updated with desktop_reacted flag
    - All state directory contents are correct
  - All tests pass successfully
  - Function is ready to be integrated into hook orchestration handlers (Tasks 10 & 11)

### 7. Mobile Notification Scheduler
- **Priority**: high
- **Status**: complete
- **Description**: Implement `schedule_mobile_notification()` that forks a detached background process sleeping 30 seconds, then checks for cancel marker. If no cancel marker and event not superseded, sends ntfy notification via existing `send_idle_notification()`. Store timer PID in `timers/${event_id}.timer`. Clean up files after completion.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Timer scheduled and PID stored; ntfy sent after 30s if no cancel; cancelled if marker exists
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `schedule_mobile_notification()` function taking event_id and message as parameters
  - Spawns fully detached background process using `( ... ) &>/dev/null & disown` pattern (same as desktop reaction)
  - Background process sleeps 30 seconds (configurable via TEST_MOBILE_DELAY for testing)
  - Checks for cancel marker `.cancel-${event_id}` before sending notification
  - Checks event metadata for `superseded: true` flag before sending notification
  - Calls existing `send_idle_notification()` to send ntfy notification if not cancelled
  - Stores timer PID in `timers/${event_id}.timer` immediately after fork for cleanup via `kill_pending_timers()`
  - Cleans up timer file after completion (whether cancelled, superseded, or successfully sent)
  - Added comprehensive test command `test-mobile-scheduler` that validates:
    - Timer is scheduled and PID file created with running process
    - Timer can be cancelled via cancel marker (Test 2)
    - Timer can be cancelled via superseded flag (Test 3)
    - Timer sends notification if not cancelled (Test 4)
    - All timer files are cleaned up after completion
  - All tests pass successfully with 5-second test delay
  - Verified integration with `kill_pending_timers()` via existing test-timer-cleanup
  - Function is ready to be integrated into hook orchestration handlers (Tasks 10 & 11)

### 8. Timer Cleanup Helper
- **Priority**: medium
- **Status**: complete
- **Description**: Add `kill_pending_timers()` function that iterates over `timers/*.timer` files, kills each PID, and removes timer files. Used by both new event handlers (to prevent duplicates) and user activity handler.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: All timer processes killed; timer files removed; no errors on empty timers/
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `kill_pending_timers()` function that gracefully handles all edge cases
  - Iterates over `timers/*.timer` files in state directory
  - Checks if each process is alive before attempting to kill (handles dead processes gracefully)
  - Removes timer files after killing (or attempting to kill)
  - Handles empty timers directory without errors
  - Added `test-timer-cleanup` test command that validates:
    - Killing of real active processes
    - Graceful handling of already-dead processes
    - Removal of all timer files
    - No errors when directory is empty
  - All tests pass successfully

### 9. User Activity Cancellation Refactor
- **Priority**: medium
- **Status**: complete
- **Description**: Refactor `stop_idle_monitor()` into `on_user_activity()`. Kill all pending timers using `kill_pending_timers()`. Create cancel markers for all active events. Clear legacy state files. Ensure graceful handling of missing state. Maintain backward compatibility with existing state file cleanup.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: User activity cancels all pending notifications; no orphan timers left; legacy cleanup preserved
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `on_user_activity()` function that handles user activity cancellation
  - Calls `kill_pending_timers()` to kill all pending mobile notification timer processes
  - Creates cancel markers (`.cancel-${event_id}`) for all active (non-superseded) events in state directory
  - Gracefully handles missing state directory (no errors if directory doesn't exist)
  - Clears legacy state files for backward compatibility (IDLE_STATE_FILE, IDLE_DETECTOR_PID_FILE)
  - Maintained backward compatibility by keeping `stop_idle_monitor()` as a wrapper that calls `on_user_activity()`
  - Added comprehensive test command `test-user-activity` that validates:
    - Timer cleanup on user activity (Test 1)
    - Cancel marker creation for active events only (Test 2) - correctly skips superseded events
    - Graceful handling of missing state directory (Test 3)
    - Legacy state file cleanup for backward compatibility (Test 4)
  - All tests pass successfully
  - Debug logging shows proper operation: "User activity detected", timer cleanup, cancel marker creation
  - Function is ready to be called from "user-activity" case in hook orchestration (already wired up)

### 10. Hook Orchestration - Stop Handler
- **Priority**: high
- **Status**: complete
- **Description**: Refactor `mark_claude_finished()` to use new infrastructure: generate session_id and event_id, initialize state directory, kill existing timers, extract transcript and summarize with Haiku, record metadata, send desktop notification with reaction detection, schedule mobile notification. Preserve existing device detection logic.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Stop hook triggers full event lifecycle; desktop notification immediate; mobile scheduled at 30s
- **Completed**: 2026-01-11
- **Notes**:
  - Refactored `mark_claude_finished()` to use full event lifecycle infrastructure
  - Implements the following flow:
    1. Initialize state directory via `initialize_state_dir()`
    2. Generate unique event ID via `generate_event_id()`
    3. Kill any pending timers from previous events via `kill_pending_timers()`
    4. Mark all previous events as superseded via `mark_events_superseded()`
    5. Extract transcript and generate summary via Haiku API (reuses existing `get_last_response()` and `summarize_with_haiku()`)
    6. Record event metadata via `record_event_metadata()` with event_type="stop"
    7. Send desktop notification with reaction detection via `send_desktop_notification_with_reaction()`
    8. Schedule mobile notification with 30s delay via `schedule_mobile_notification()`
  - Preserves device detection logic but now uses it for logging only (device-aware routing will be implemented in Task 12)
  - Default summary is "Response ready" if transcript unavailable or summarization fails
  - Added comprehensive test command `test-stop-handler` that validates:
    - Full event lifecycle (event ID generation, metadata creation, timer scheduling)
    - Haiku summary generation from mock transcript
    - Event supersession when second event is triggered
    - Timer cleanup when superseded events occur
    - Desktop reaction detection (cancel marker + metadata update after 2s)
  - All tests pass successfully with proper state management
  - Debug logging shows complete event lifecycle: "Stop hook complete - event: {id}, desktop notified, mobile scheduled"
  - Function is ready for production use; device-aware routing (Task 12) will optimize for mobile-only sessions

### 11. Hook Orchestration - PermissionRequest Handler
- **Priority**: high
- **Status**: complete
- **Description**: Implement `on_permission_request()` with same pattern as Stop handler but using `get_permission_summary()` for message. Parse tool_name from hook stdin JSON. Follow unified flow: ID generation, metadata, desktop notify, mobile schedule. Replace existing permission-request case.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: PermissionRequest hook triggers full lifecycle; context-aware message shown
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `on_permission_request()` function following the same pattern as `mark_claude_finished()`
  - Implements the following flow:
    1. Parse tool_name from hook stdin JSON via jq
    2. Initialize state directory via `initialize_state_dir()`
    3. Generate unique event ID via `generate_event_id()`
    4. Kill any pending timers from previous events via `kill_pending_timers()`
    5. Mark all previous events as superseded via `mark_events_superseded()`
    6. Generate permission-aware message via `get_permission_summary(tool_name)`
    7. Record event metadata via `record_event_metadata()` with event_type="permission_request"
    8. Send desktop notification with reaction detection via `send_desktop_notification_with_reaction()`
    9. Schedule mobile notification with 30s delay via `schedule_mobile_notification()`
  - Replaced existing permission-request case (28 lines of legacy code) with single call to `on_permission_request()`
  - Uses permission-aware messages: "Waiting for your answer", "Waiting for permission: File edit", etc.
  - Default message is "Waiting for permission" if get_permission_summary returns empty
  - Added comprehensive test command `test-permission-handler` that validates:
    - Full event lifecycle with AskUserQuestion tool (Test 1)
    - Different tool types generate correct permission messages (Test 2: Edit, Bash)
    - Event supersession works correctly between permission requests (Test 3)
    - Timer cleanup when superseded events occur
    - Desktop reaction detection (cancel marker + metadata update after 2s) (Test 4)
  - Verified with direct invocation tests:
    - AskUserQuestion → "Waiting for your answer" ✓
    - Write/Edit → "Waiting for permission: File edit" ✓
    - Bash → "Waiting for permission: Run command" ✓
  - Debug logging shows complete event lifecycle: "PermissionRequest hook complete - event: {id}, desktop notified, mobile scheduled"
  - Function is ready for production use; device-aware routing (Task 12) will optimize for mobile-only sessions

### 12. Device-Aware Routing Integration
- **Priority**: medium
- **Status**: complete
- **Description**: Integrate desktop notification sender with existing device detection. When `DEVICE_TYPE=desktop`, use new desktop notification with reaction detection + mobile scheduler. When `DEVICE_TYPE=mobile` (SSH/mosh), skip desktop notification and send ntfy immediately (no 30s delay). Existing `detect_device_type()` already works; just wire it into new handlers.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Local sessions get desktop + delayed mobile; SSH sessions get ntfy immediately
- **Completed**: 2026-01-11
- **Notes**:
  - Modified `mark_claude_finished()` to use device-aware routing logic
  - Modified `on_permission_request()` to use device-aware routing logic
  - Desktop devices (no SSH_CONNECTION/MOSH_CONNECTION):
    - Send desktop notification with reaction detection (immediate)
    - Schedule mobile notification with 30s delay
    - Existing behavior preserved
  - Mobile devices (SSH_CONNECTION or MOSH_CONNECTION set):
    - Skip desktop notification (osascript not available in SSH)
    - Send ntfy notification immediately via `send_idle_notification()`
    - No timer scheduled (no delay needed)
  - Added comprehensive test command `test-device-routing` that validates:
    - Device type detection for desktop, SSH, and Mosh environments (Test 1-3)
    - Stop handler routing for both desktop and mobile (Test 4a-4b)
    - PermissionRequest handler routing for both desktop and mobile (Test 5a-5b)
    - Debug logging shows correct routing path taken
  - All tests pass successfully
  - Preserves all existing event lifecycle management (metadata, supersession, timer cleanup)
  - Debug logging clearly indicates which routing path is taken

### 13. Legacy Cleanup and Migration
- **Priority**: low
- **Status**: complete
- **Description**: Remove or deprecate old state file patterns (`/tmp/claude-idle-state-*`, `/tmp/claude-idle-detector-*.pid`, `/tmp/claude-transcript-path-*`, `/tmp/claude-permission-context-*`) once new system is stable. Add migration logic to clean up old files on first run of new system. Update `notify-with-summary` case to use new infrastructure or remove if no longer needed.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Old state files cleaned up; no file accumulation; system runs cleanly
- **Completed**: 2026-01-11
- **Notes**:
  - Implemented `cleanup_legacy_state()` function that removes all legacy file patterns:
    - `/tmp/claude-idle-state-*` (old idle monitor state files)
    - `/tmp/claude-idle-detector-*.pid` (old idle monitor PID files)
    - `/tmp/claude-transcript-path-*` (old transcript path communication files)
    - `/tmp/claude-permission-context-*` (old permission context communication files)
  - Cleanup is automatically called from `initialize_state_dir()` on first run (when state directory is created)
  - Cleanup uses `rm -f` with glob patterns, counts files before deletion, and logs to debug log
  - Gracefully handles missing files (no errors when no legacy files exist)
  - Kept legacy variable definitions (`IDLE_STATE_FILE`, `IDLE_DETECTOR_PID_FILE`, etc.) for backward compatibility
    - These are still used by `on_user_activity()` to clean up any remaining legacy processes/files
  - Marked `notify-with-summary` case as DEPRECATED with comment
    - Kept for backward compatibility in case external scripts still call it
    - New infrastructure uses `mark_claude_finished()` and `on_permission_request()` directly
  - `start_idle_monitor()` function is now dead code (not called from main case statement)
  - Added comprehensive test command `test-legacy-cleanup` that validates:
    - Direct cleanup function call removes all test legacy files (Test 1)
    - Cleanup runs automatically during state directory initialization (Test 2)
    - Graceful handling when no legacy files exist (Test 3)
  - All tests pass successfully
  - System now runs cleanly without file accumulation in /tmp

### 14. Reaction Detection Fix (Critical Bug)
- **Priority**: high
- **Status**: complete
- **Description**: Fix critical design flaw in `send_desktop_notification_with_reaction()` that unconditionally creates cancel markers after 2-second delay, defeating mobile backup when user is AFK. Remove the `(sleep 2; touch "$cancel_file") & disown` block. Let real user activity (UserPromptSubmit hook via `on_user_activity()`) handle cancel marker creation instead. This ensures mobile notifications fire correctly when user is away from keyboard.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Desktop notification sends without implicit cancellation
  - Cancel markers only created on real user activity (keystrokes)
  - Mobile notification fires at 30s if no user activity
  - Mobile notification cancels if user types before 30s
- **Completed**: 2026-01-11
- **Notes**:
  - Removed background process that created cancel markers after 2-second delay
  - Removed automatic `desktop_reacted` flag update (now only set via user activity)
  - Updated function comment to reflect new design: cancel via user activity only
  - Desktop notification still sends immediately via osascript
  - Updated three test functions to verify new behavior:
    - `test-desktop-reaction`: Verifies cancel marker NOT auto-created
    - `test-stop-handler` (Test 3): Verifies no auto-cancel after desktop notification
    - `test-permission-handler` (Test 4): Verifies no auto-cancel after desktop notification
  - All tests now expect cancel markers to NOT exist unless user activity occurs
  - Script syntax validated successfully
  - Mobile notifications will now correctly fire at 30s when user is AFK
  - Mobile notifications will correctly cancel when user types (via UserPromptSubmit hook)

### 15. Osascript String Escaping (Critical Bug)
- **Priority**: high
- **Status**: pending
- **Description**: Fix silent notification failures caused by unescaped quotes and backslashes in notification messages. Create `_escape_for_osascript()` helper function that escapes backslashes first, then quotes, then converts newlines to spaces. Apply to all osascript calls. Log errors instead of suppressing them with `2>/dev/null || true`.
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Quotes in summaries display correctly: `The user said "hello"`
  - Backslashes in summaries display correctly: `C:\Users\name\file.txt`
  - Newlines handled without breaking command
  - Failures logged to debug log instead of silently suppressed
- **Note**: Quick fix - ~10 lines for helper function, ~5 line changes per calling function

### 16. Terminal-Notifier Click Handler (Optional Enhancement)
- **Priority**: low
- **Status**: pending
- **Description**: Implement `send_desktop_notification_with_click_handler()` that uses terminal-notifier's `-execute` parameter for true click-based notification dismissal. Creates cancel marker when user clicks notification. Falls back gracefully to osascript if terminal-notifier not installed. Works alongside user activity cancellation (both paths create cancel markers, idempotent).
- **Files**: `~/.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Clicking notification cancels mobile notification
  - Works with or without terminal-notifier installed
  - Graceful fallback to osascript
- **Note**: Optional enhancement - terminal-notifier via `brew install terminal-notifier`

### 17. Notification Click Handler Script (Optional Enhancement)
- **Priority**: low
- **Status**: pending
- **Description**: Create `~/.local/bin/notification-handler.sh` that parses JSON payload, focuses Ghostty terminal via AppleScript (matching repo_path), and navigates to tmux pane. Recover session if missing. This enables click-through navigation from desktop notifications. Requires terminal-notifier with -execute parameter (not osascript).
- **Files**: `~/.local/bin/notification-handler.sh`, `~/.claude/hooks/idle-detector.sh`
- **Acceptance**: Clicking notification focuses correct terminal and tmux pane
- **Note**: Depends on Ghostty AppleScript support and terminal-notifier installation; can be skipped

## Notes

### Architectural Decisions
- **Real user activity for reaction detection** (Spec 13 fix): Cancel markers are created only on real user activity (UserPromptSubmit hook), not via heuristic 2-second delay. This ensures mobile notifications fire correctly when user is AFK.
- **Session isolation via tmux pane ID**: Each tmux pane gets independent notification state, preventing cross-talk between parallel Claude sessions.
- **Supersession model**: New events mark old events as superseded rather than deleting, preserving audit trail while preventing duplicate notifications.
- **Background timer detachment**: Timers use full process detachment (exec redirect, disown) to survive parent process exit.
- **Mobile-first for SSH**: SSH sessions get immediate ntfy (no desktop notification available), not delayed.
- **Proper string escaping** (Spec 15): All osascript notifications use `_escape_for_osascript()` to handle quotes, backslashes, and newlines safely.
- **Optional click detection** (Spec 14): terminal-notifier integration provides click-based dismissal when available, with graceful fallback to osascript.

### Dependencies
- `jq` required for JSON manipulation (already in use)
- `uuidgen` preferred for event IDs (fallback to timestamp+random)
- `terminal-notifier` optional for enhanced click handling (osascript fallback)
- Ghostty with AppleScript support optional for terminal focus on click (nice-to-have)

### Migration Path
- Existing ntfy integration preserved and reused
- Existing Haiku summarization reused
- Device detection already complete, just needs routing integration
- Settings.json already has correct hook configuration for Stop, UserPromptSubmit, PermissionRequest
- Backward compatible: new system can coexist with old state files during transition

### Testing Strategy
- Each function testable in isolation via manual invocation
- Debug logging to `/tmp/claude-hook-debug.log`
- Timer cleanup on session end prevents file accumulation
- State directory in `/tmp/` auto-cleaned on reboot
- Existing test commands preserved: `test-detect`, `test-desktop`, `test-summary`, `test-permission`

### Implementation Order
Recommended order based on dependencies:
1. ✅ Session State Infrastructure (foundation)
2. ✅ Event ID and Metadata System (foundation)
3. ✅ Permission Summary Function (quick refactor)
4. ✅ Timer Cleanup Helper (needed for handlers)
5. ✅ Desktop Notification with Reaction Detection (core feature)
6. ✅ Mobile Notification Scheduler (core feature)
7. ✅ Hook Orchestration - Stop Handler (integration)
8. ✅ Hook Orchestration - PermissionRequest Handler (integration)
9. ✅ User Activity Cancellation Refactor (integration)
10. ✅ Device-Aware Routing Integration (polish)
11. ✅ tmux Context Capture (enhancement)
12. ✅ Notification Payload Builder (enhancement)
13. ✅ Legacy Cleanup and Migration (cleanup)
14. ⏳ **Reaction Detection Fix** (critical bug - Spec 13)
15. ⏳ **Osascript String Escaping** (critical bug - Spec 15)
16-17. Optional enhancements (terminal-notifier click handler, navigation handler - Specs 04, 14)

## Generated
- Date: 2026-01-11T21:00:00Z
- Mode: planning
- Specs analyzed: 15 (01-15 in specs/)
