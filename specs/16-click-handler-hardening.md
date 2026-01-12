# Spec 16: Click Handler Hardening

## Overview

Follow-up improvements identified during code review of the terminal-notifier click handler implementation (Tasks 16-17). These address robustness, error handling, and test coverage gaps.

## Priority

Low - The current implementation is functional. These are hardening improvements for production confidence.

## Issues to Address

### 1. JSON Schema Validation

**Problem**: `notification-handler.sh` parses JSON via jq but doesn't validate schema before extraction. Malformed payloads could cause silent failures with empty field values.

**Current behavior**:
```bash
EVENT_ID=$(echo "$PAYLOAD" | jq -r '.event_id // empty' 2>/dev/null || echo "")
# If jq silently fails, EVENT_ID could be empty but pass the -z check
```

**Required fix**:
- Add `jq -e` flag for strict parsing
- Validate all required fields are non-empty after extraction
- Exit with clear error if payload is malformed

**Acceptance**:
- Malformed JSON payloads cause explicit error (not silent failure)
- Missing required fields (event_id) cause explicit error
- Error messages logged to debug log with payload snippet

### 2. Atomic Payload File Writes

**Problem**: Race condition between payload file creation and notification handler execution. Multiple concurrent notifications could conflict.

**Current behavior**:
```bash
echo "$payload" > "$payload_file"
```

**Required fix**:
- Write to temp file first, then atomic mv
- Or use file locking (flock) if available

**Acceptance**:
- Concurrent notifications don't corrupt each other's payloads
- Partial writes never visible to handler script

### 3. tmux Navigation Error Handling

**Problem**: `notification-handler.sh` logs warnings when tmux operations fail but doesn't provide feedback. Script's success/failure contract is unclear.

**Current behavior**:
```bash
if tmux select-window -t "${session}:${window}" >> "$DEBUG_LOG" 2>&1; then
    # success
else
    log_debug "WARNING: Failed to select window"
    # continues silently
fi
```

**Required fix**:
- Define exit code semantics (0 = full success, 1 = partial, 2 = complete failure)
- Document expected behavior in script header
- Consider: should failure to navigate trigger a fallback notification?

**Acceptance**:
- Exit codes documented in script header
- Callers can distinguish full success from partial success
- Debug log shows clear success/failure summary

### 4. Clarify jq Dependency Status

**Problem**: Documentation says jq is "Required" but code has fallback paths. Behavior is inconsistent.

**Current state**:
- IMPLEMENTATION_PLAN.md: "jq - JSON manipulation (install: brew install jq)"
- idle-detector.sh: Falls back to osascript if jq unavailable
- notification-handler.sh: Exits with error if jq unavailable

**Required fix**:
- Make behavior consistent: either jq is strictly required (both scripts exit) or both have fallbacks
- Update documentation to match actual behavior
- Recommend: jq is required for click-through features, osascript fallback works without jq

**Acceptance**:
- Documentation matches implementation
- Clear message when jq missing: what works, what doesn't

### 5. Test Coverage for P1/P2 Fixes

**Problem**: Test commands only cover happy path. Edge cases from P1/P2 fixes aren't tested.

**Missing test cases**:
- Payload write failure recovery (disk full, permissions)
- Cancel marker file permission verification (should be 600)
- Malformed event_id values
- Stale file cleanup verification (files >1 day old)
- jq unavailable fallback path

**Required fix**:
- Add test cases to `test-click-handler` and `test-notification-handler`
- Or create new `test-click-handler-edge-cases` command

**Acceptance**:
- Each P1/P2 fix has corresponding test case
- Tests verify both success and failure paths

### 6. Session ID Collision Prevention (Optional)

**Problem**: Session ID assumes `hostname:session:pane` uniqueness. On containerized systems with shared hostnames, collision possible.

**Current format**: `wintermute:dotfiles:10`

**Suggested improvement**:
- Add PID or timestamp component for additional uniqueness
- Format: `hostname:session:pane:pid` or `hostname:session:pane:timestamp`

**Acceptance**:
- Document collision assumptions OR
- Add PID to session ID format

## Implementation Notes

- Issues 1-5 are recommended before considering this "production ready"
- Issue 6 is optional/future consideration
- All changes should maintain backward compatibility with existing state directories

## Testing Strategy

- Extend existing test commands with edge case coverage
- Add integration test: click notification -> cancel marker -> mobile cancelled
- Test on fresh system without jq installed to verify fallback behavior

## Dependencies

None - uses existing infrastructure.
