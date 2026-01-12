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
- **Status**: pending
- **Description**: Add strict JSON validation to `notification-handler.sh`. Use `jq -e` flag for strict parsing. Validate all required fields (event_id) are non-empty after extraction. Exit with clear error if payload is malformed. Log payload snippet on failure for debugging.
- **Files**: `bin/notification-handler.sh`
- **Acceptance**:
  - Malformed JSON payloads cause explicit error (not silent failure)
  - Missing required fields (event_id) cause explicit error with message
  - Error messages logged to debug log with payload snippet (first 100 chars)

### 2. Atomic Payload File Writes
- **Priority**: medium
- **Status**: complete
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
- **Status**: pending
- **Description**: Define and document exit code semantics for `notification-handler.sh`. Add header documentation explaining: 0 = full success (terminal focused, tmux navigated, marker created), 1 = partial success (some operations failed but marker created), 2 = complete failure (critical error, no marker). Add summary log line at end showing success/failure status.
- **Files**: `bin/notification-handler.sh`
- **Acceptance**:
  - Exit codes documented in script header comment
  - Script exits with appropriate code based on operation results
  - Debug log shows clear success/failure summary at end

### 4. Clarify jq Dependency Documentation
- **Priority**: low
- **Status**: pending
- **Description**: Update documentation to clarify jq dependency behavior. Make behavior consistent: jq is required for click-through features, osascript fallback works without jq for basic notifications. Add clear message when jq is missing explaining what works and what doesn't.
- **Files**: `IMPLEMENTATION_PLAN.md` (documentation only)
- **Acceptance**:
  - Documentation clearly states: "jq required for click-through, basic notifications work without"
  - Current fallback behavior in idle-detector.sh already correct (logs and falls back)
  - notification-handler.sh correctly requires jq (no fallback possible for JSON parsing)

### 5. Test Coverage for Edge Cases
- **Priority**: medium
- **Status**: pending
- **Description**: Add test cases for edge cases not covered by existing tests. Add to existing `test-click-handler` command or create new `test-click-handler-edge-cases`. Test cases: malformed JSON payload, missing event_id, jq unavailable fallback verification, stale file cleanup verification.
- **Files**: `.claude/hooks/idle-detector.sh`
- **Acceptance**:
  - Test for malformed JSON payload handling
  - Test for missing required fields
  - Test verifies stale payload file cleanup (>1 day old files)
  - All tests produce clear pass/fail output

### 6. Session ID Collision Documentation (Optional)
- **Priority**: low
- **Status**: pending
- **Description**: Document session ID collision assumptions in code comments. The current format `hostname:session:pane` is unique enough for typical usage. Adding PID would break state persistence across shell restarts. Document this trade-off rather than changing behavior.
- **Files**: `.claude/hooks/lib/session.sh`
- **Acceptance**:
  - Comment explains format and uniqueness assumptions
  - Notes containerized systems may need additional consideration
  - No code changes required (documentation only)

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
1. Atomic Payload File Writes (Task 2) - prevents race conditions
2. JSON Schema Validation (Task 1) - depends on Task 2 for stable test environment
3. Test Coverage for Edge Cases (Task 5) - validates Tasks 1-2
4. tmux Navigation Exit Codes (Task 3) - documentation/minor code changes
5. jq Dependency Documentation (Task 4) - documentation only
6. Session ID Documentation (Task 6) - documentation only

## Generated
- Date: 2026-01-11T22:00:00Z
- Mode: planning
- Specs analyzed: 16 (click handler hardening)
