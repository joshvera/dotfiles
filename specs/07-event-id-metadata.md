# Spec: Event ID Generation and Metadata

## Purpose
Generate unique event identifiers for each hook invocation and record event metadata in JSON format for tracking notification state, deduplication, and cancellation logic.

## Inputs
- Session ID (from Spec 04)
- Event type: "Stop" | "PermissionRequest"
- Summary text (from Haiku or context-aware fallback)
- Timestamp (current Unix epoch)

## Outputs
- `EVENT_ID`: UUID4 string (lowercase)
- `metadata.json`: JSON file in state directory with event details
- Active event registration in state directory

## Metadata Schema
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "Stop",
  "timestamp": 1673456789,
  "session_id": "mac:main:%5",
  "summary": "Implemented user authentication feature",
  "desktop_notified": true,
  "desktop_reacted": false,
  "mobile_sent": false,
  "superseded": false
}
```

## Dependencies
- `uuidgen` command (macOS/Linux) or fallback random generation
- `jq` for JSON manipulation
- State directory from Spec 04

## Key Decisions

### Decision 1: UUID Format
Use lowercase UUID4 for event IDs. Rationale: Consistent format, guaranteed uniqueness, safe for filenames.

### Decision 2: Fallback Event ID
If `uuidgen` unavailable, generate `RANDOM-TIMESTAMP-RANDOM` format. Not cryptographically unique but sufficient for short-lived notification deduplication.

### Decision 3: Atomic Metadata Updates
Use write-to-temp-then-move pattern for metadata.json updates to prevent corruption from concurrent reads during background timer execution.

### Decision 4: Supersession Marking
When a new event arrives before the previous event's mobile timer fires, mark the old event as `superseded: true` rather than deleting it. Preserves audit trail.

## Implementation

```bash
generate_event_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback: timestamp-random-random
        echo "$(date +%s)-${RANDOM}-${RANDOM}"
    fi
}

record_event_metadata() {
    local session_id="$1"
    local event_id="$2"
    local event_type="$3"
    local summary="${4:-}"

    local state_dir="/tmp/claude-notification-state-${session_id}"
    local metadata_file="$state_dir/metadata.json"

    # Mark any existing event as superseded
    if [[ -f "$metadata_file" ]]; then
        jq '.superseded = true' "$metadata_file" > "${metadata_file}.old" 2>/dev/null || true
    fi

    # Create new metadata
    local metadata
    metadata=$(jq -n \
        --arg eid "$event_id" \
        --arg etype "$event_type" \
        --arg ts "$(date +%s)" \
        --arg sid "$session_id" \
        --arg sum "$summary" \
        '{
            event_id: $eid,
            event_type: $etype,
            timestamp: ($ts | tonumber),
            session_id: $sid,
            summary: $sum,
            desktop_notified: false,
            desktop_reacted: false,
            mobile_sent: false,
            superseded: false
        }')

    echo "$metadata" > "${metadata_file}.tmp"
    mv "${metadata_file}.tmp" "$metadata_file"
}

update_event_field() {
    local session_id="$1"
    local field="$2"
    local value="$3"

    local metadata_file="/tmp/claude-notification-state-${session_id}/metadata.json"

    if [[ -f "$metadata_file" ]]; then
        jq --arg val "$value" ".$field = (\$val | if . == \"true\" then true elif . == \"false\" then false else . end)" \
            "$metadata_file" > "${metadata_file}.tmp"
        mv "${metadata_file}.tmp" "$metadata_file"
    fi
}
```

## Verification
```bash
# Test event ID generation
event_id=$(generate_event_id)
echo "$event_id"
# Expected: lowercase UUID like 550e8400-e29b-41d4-a716-446655440000

# Test metadata recording
session_id="test:main:%0"
mkdir -p "/tmp/claude-notification-state-${session_id}/timers"
record_event_metadata "$session_id" "$event_id" "Stop" "Test summary"
cat "/tmp/claude-notification-state-${session_id}/metadata.json" | jq .
# Expected: valid JSON with all fields

# Test field update
update_event_field "$session_id" "desktop_notified" "true"
cat "/tmp/claude-notification-state-${session_id}/metadata.json" | jq .desktop_notified
# Expected: true
```

## Implementation Location
Add functions to `~/.claude/hooks/idle-detector.sh`:
- `generate_event_id()` - UUID generation
- `record_event_metadata()` - metadata file creation
- `update_event_field()` - atomic field updates
