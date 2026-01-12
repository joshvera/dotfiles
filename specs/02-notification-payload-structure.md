# Spec: Notification Payload Structure

## Purpose
Define standardized JSON payload format passed through notification system (terminal-notifier `-userInfo` flag) to ensure notification-handler.sh receives all required context for click handling.

## Inputs
- Event type: string ("notification", "stop", "idle-notification")
- Current working directory: string (e.g., "/Users/vera/github/dotfiles")
- Repository path: string (may differ from cwd, used for Ghostty terminal matching)
- tmux context: session, window, pane identifiers (optional, captured by Spec 01)
- Transcript path: optional string path to transcript file
- Permission context: optional string describing permission request context

## Outputs
- JSON payload object (validated before sending to notification)
- Payload passed to notification-handler.sh via command-line argument (shell-escaped)

## Payload Structure
```json
{
  "event_type": "idle-notification",
  "repo_path": "/Users/vera/github/dotfiles",
  "cwd": "/Users/vera/github/dotfiles",
  "tmux_target": "main:0.0",
  "tmux_session": "main",
  "transcript_path": "/path/to/transcript.md",
  "permission_context": null,
  "timestamp": "2026-01-11T20:23:11Z"
}
```

## Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | string | Yes | One of: "notification", "stop", "idle-notification" |
| `repo_path` | string | Yes | Directory containing .git or project root for Ghostty matching |
| `cwd` | string | Yes | Current working directory at notification time |
| `tmux_target` | string | No | Format: "SESSION:WINDOW.PANE"; null if not in tmux |
| `tmux_session` | string | No | Session name only; null if not in tmux |
| `transcript_path` | string | No | Path to transcript file if available |
| `permission_context` | string | No | Additional context for permission requests |
| `timestamp` | string | Yes | ISO 8601 timestamp of notification creation |

## Dependencies
- `jq` (for JSON manipulation and validation)
- Bash 4.0+ (for JSON string construction)
- Context from Spec 01 (tmux-context-capture)

## Key Decisions

### Decision 1: Redundant Fields
Include both `tmux_target` (combined) and `tmux_session` (session only) for flexibility. notification-handler.sh may need just session for recovery logic.

### Decision 2: Repo Path Detection
`repo_path` should be the deepest parent directory containing `.git`, not cwd. Rationale: Ghostty terminals may open subdirectories; we need the project root for matching.

### Decision 3: Null vs Empty String
Use JSON `null` for optional missing fields (not empty string). Enables handler to distinguish "not captured" from "empty value".

### Decision 4: Timestamp Format
Use ISO 8601 (RFC 3339) for machine readability and logging consistency.

## Verification
```bash
# Validate JSON schema
payload='{"event_type":"idle-notification","repo_path":"/Users/vera/github/dotfiles","cwd":"/Users/vera/github/dotfiles","tmux_target":"main:0.0","tmux_session":"main","transcript_path":null,"permission_context":null,"timestamp":"2026-01-11T20:23:11Z"}'

# Ensure valid JSON
echo "$payload" | jq empty && echo "Valid JSON"

# Extract fields for use
event=$(echo "$payload" | jq -r '.event_type')
repo=$(echo "$payload" | jq -r '.repo_path')
target=$(echo "$payload" | jq -r '.tmux_target')
```

## Implementation Location
In `~/.claude/hooks/notifier-desktop.sh` and modified `~/.claude/hooks/notifier.sh`:
- Build payload object after context capture (Spec 01)
- Validate with `jq` before passing to terminal-notifier
- Escape for shell argument passing (`jq -c .` for compact output)
- Pass to `-execute` handler script
