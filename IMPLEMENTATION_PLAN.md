# Implementation Plan

## Overview

Hardening improvements for the terminal-notifier click handler implementation (Spec 16). These address robustness, error handling, and test coverage gaps identified during code review.

## Current State

Tasks 1-17 from the previous plan are complete. The notification system is functional with:
- Desktop notifications via terminal-notifier (with osascript fallback)
- Click-through navigation to tmux panes via notification-handler.sh
- Mobile notification scheduling with cancellation support
- Session state management and event lifecycle tracking

## Tasks

### 1. JSON Schema Validation in notification-handler.sh
- **Priority**: medium
- **Status**: completed
- **Description**: Add strict JSON validation to `notification-handler.sh`. Use `jq -e` flag for strict parsing. Validate all required fields (event_id) are non-empty after extraction. Exit with clear error if payload is malformed. Log payload snippet on failure for debugging.
- **Files**: `bin/notification-handler.sh`
- **Acceptance**:
  - Malformed JSON payloads cause explicit error (not silent failure)
  - Missing required fields (event_id) cause explicit error with message
  - Error messages logged to debug log with payload snippet (first 100 chars)
- **Implementation Notes**:
  - Added upfront JSON validation using `jq -e .` that fails fast on malformed JSON
  - Changed all field extractions to use `jq -e` for strict parsing
  - Added payload snippet logging (first 100 chars) on both malformed JSON and missing event_id errors
  - Improved error message for missing event_id to be more explicit about the field requirement

### 2. Atomic Payload File Writes
- **Priority**: medium
- **Status**: completed
- **Description**: Fix race condition in `send_desktop_notification_with_click_handler()` where payload file creation could conflict with concurrent notifications. Write to temp file first, then atomic `mv` to final location.
- **Files**: `.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Payload writes use atomic pattern: write to `.tmp.$$`, then `mv`
  - Concurrent notifications don't corrupt each other's payloads
  - Partial writes never visible to handler script
- **Implementation Notes**:
  - Added temp file with PID suffix (`.tmp.$$`) for uniqueness across concurrent notifications
  - Write to temp file first with restrictive permissions (umask 0077)
  - Atomic `mv` to final location prevents race condition
  - Added error handling for both write and move operations with cleanup on failure

### 3. tmux Navigation Exit Code Semantics
- **Priority**: low
- **Status**: completed
- **Description**: Define and document exit code semantics for `notification-handler.sh`. Add header documentation explaining: 0 = full success (terminal focused, tmux navigated, marker created), 1 = partial success (some operations failed but marker created), 2 = complete failure (critical error, no marker). Add summary log line at end showing success/failure status.
- **Files**: `bin/notification-handler.sh`
- **Acceptance**:
  - Exit codes documented in script header comment
  - Script exits with appropriate code based on operation results
  - Debug log shows clear success/failure summary at end
- **Implementation Notes**:
  - Added comprehensive header documentation explaining three exit codes (0, 1, 2)
  - Added tracking variables: MARKER_CREATED, TERMINAL_FOCUSED, TMUX_NAVIGATED
  - Updated all critical errors (malformed JSON, missing fields, missing dependencies) to exit with code 2
  - Added success tracking for marker creation, terminal focus, and tmux navigation operations
  - Final status determination: exit 2 if no marker created, exit 1 if marker created but other operations failed, exit 0 if all succeeded
  - Added detailed summary log line showing operation status and exit code

### 4. Clarify jq Dependency Documentation
- **Priority**: low
- **Status**: completed
- **Description**: Update documentation to clarify jq dependency behavior. Make behavior consistent: jq is required for click-through features, osascript fallback works without jq for basic notifications. Add clear message when jq is missing explaining what works and what doesn't.
- **Files**: `IMPLEMENTATION_PLAN.md` (documentation only)
- **Acceptance**:
  - Documentation clearly states: "jq required for click-through, basic notifications work without"
  - Current fallback behavior in idle-detector.sh already correct (logs and falls back)
  - notification-handler.sh correctly requires jq (no fallback possible for JSON parsing)
- **Implementation Notes**:
  - Verified existing "jq Dependency Behavior" section (lines 131-140) accurately documents the behavior
  - Confirmed idle-detector.sh has correct fallback: logs "jq not found, falling back to osascript" (line 669) and falls through to osascript notification (no click-through)
  - Confirmed notification-handler.sh requires jq: exits with code 2 and message "ERROR: jq not found (required for JSON parsing)" (line 34)
  - Documentation table clearly shows: jq available = full click-through functionality, jq missing = osascript fallback (basic notifications only)
  - No code changes needed, documentation already complete and accurate

### 5. Test Coverage for Edge Cases
- **Priority**: medium
- **Status**: completed
- **Description**: Add test cases for edge cases not covered by existing tests. Add to existing `test-click-handler` command or create new `test-click-handler-edge-cases`. Test cases: malformed JSON payload, missing event_id, jq unavailable fallback verification, stale file cleanup verification.
- **Files**: `.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Test for malformed JSON payload handling
  - Test for missing required fields
  - Test verifies stale payload file cleanup (>1 day old files)
  - All tests produce clear pass/fail output
- **Implementation Notes**:
  - Added new `test-click-handler-edge-cases` command with 6 test cases
  - Test 1: Validates malformed JSON is rejected with error message
  - Test 2: Validates missing event_id field is detected
  - Test 3: Validates empty event_id field is detected
  - Test 4: Verifies stale payload cleanup code exists (find command behavior varies by OS)
  - Test 5: Verifies jq dependency check exists in notification-handler.sh
  - Test 6: Validates error messages include payload snippet (first 100 chars)
  - Pre-flight checks verify handler script contains expected error patterns before tests run
  - Unique markers (EDGE_TEST_N_timestamp) provide test isolation in debug log
  - Uses BASH_SOURCE for portable path resolution across systems
  - Updated usage message to include new test command

### 6. Session ID Collision Documentation (Optional)
- **Priority**: low
- **Status**: completed
- **Description**: Document session ID collision assumptions in code comments. The current format `hostname:session:pane` is unique enough for typical usage. Adding PID would break state persistence across shell restarts. Document this trade-off rather than changing behavior.
- **Files**: `.claude/hooks/lib/session.sh`
- **Acceptance**:
  - Comment explains format and uniqueness assumptions
  - Notes containerized systems may need additional consideration
  - No code changes required (documentation only)
- **Implementation Notes**:
  - Added comprehensive documentation block explaining session ID format
  - Documented uniqueness guarantees for tmux and non-tmux environments
  - Explained why PID is not included: would break state persistence across shell restarts
  - Listed collision scenarios (containerized systems, hostname conflicts, session name reuse)
  - Documented design trade-off: state persistence prioritized over perfect collision avoidance
  - No code changes, documentation only as planned

## Notes

### Architectural Decisions
- **Atomic writes over file locking**: Using atomic mv pattern instead of flock because flock availability varies across systems and temp file + mv is simpler and equally effective for this use case.
- **Exit codes vs exceptions**: Shell scripts use exit codes for status communication. Three-level exit codes (0/1/2) provide sufficient granularity without overcomplicating error handling.
- **Session ID format unchanged**: Adding PID to session ID would break state persistence when shell restarts. Current format is "good enough" for typical usage patterns.

### Dependencies
No new dependencies. All changes use existing tools (jq, bash builtins).

### Testing Strategy
- Extend existing test commands with edge case coverage
- Manual verification on systems with/without terminal-notifier
- No new test infrastructure required

### Implementation Order
Recommended order based on priority and dependencies:
1. ~~Atomic Payload File Writes (Task 2)~~ - COMPLETE
2. ~~JSON Schema Validation (Task 1)~~ - COMPLETE
3. ~~Test Coverage for Edge Cases (Task 5)~~ - COMPLETE
4. ~~tmux Navigation Exit Codes (Task 3)~~ - COMPLETE
5. ~~jq Dependency Documentation (Task 4)~~ - COMPLETE
6. ~~Session ID Documentation (Task 6)~~ - COMPLETE (documentation only)

### jq Dependency Behavior

**Current behavior (documented for Task 4)**:

| Component | jq Available | jq Missing |
|-----------|-------------|------------|
| idle-detector.sh | Full functionality with click-through | Falls back to osascript (no click-through) |
| notification-handler.sh | Parses JSON, navigates tmux | Exits with error (click-through disabled) |

**Summary**: jq is required for click-through features. Basic notifications work without jq via osascript fallback.

## Generated
- Date: 2026-01-11T22:30:00Z
- Mode: planning
- Specs analyzed: 16 (click handler hardening)
