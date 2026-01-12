# Spec: tmux Context Capture

## Purpose
Capture tmux session, window, and pane identifiers during Claude Code hook execution so notifications can later navigate to the correct terminal pane.

## Inputs
- Hook execution environment with `$TMUX` variable set (indicates running inside tmux)
- Current working directory (`$PWD`)
- Existing state files: `/tmp/claude-idle-state-{project}`, `/tmp/claude-transcript-path-{project}`

## Outputs
- `TMUX_SESSION`: tmux session name (string, e.g., "main")
- `TMUX_WINDOW`: window index (integer, e.g., "0")
- `TMUX_PANE`: pane index (integer, e.g., "0")
- `TMUX_TARGET`: combined pane identifier (string, format `SESSION:WINDOW.PANE`, e.g., "main:0.0")

## Dependencies
- `tmux` command-line tool (must be in PATH)
- Bash 4.0+
- Running inside a tmux session (detectable via `$TMUX` variable)

## Key Decisions

### Decision 1: When to Capture
Capture context at notification trigger time (in `notifier.sh`), not at idle state detection. Rationale: Session may change between idle-detector and notification time.

### Decision 2: Fallback Behavior
If `$TMUX` is empty or tmux command fails, set all variables to empty string/null. Consumer (notification-handler.sh) will gracefully skip tmux navigation if null.

### Decision 3: Format
Use standard tmux target syntax `SESSION:WINDOW.PANE` for compatibility with `tmux` commands and JSON payloads. Example: `"main:0.0"`.

## Verification
```bash
# Test in tmux session
TMUX=... bash -c '
  TMUX_SESSION=$(tmux display-message -p "#{session_name}")
  TMUX_WINDOW=$(tmux display-message -p "#{window_index}")
  TMUX_PANE=$(tmux display-message -p "#{pane_index}")
  TMUX_TARGET="${TMUX_SESSION}:${TMUX_WINDOW}.${TMUX_PANE}"
  echo "Session: $TMUX_SESSION, Window: $TMUX_WINDOW, Pane: $TMUX_PANE"
  echo "Target: $TMUX_TARGET"
'

# Verify format in notification payload
jq '.tmux_target' notification_payload.json  # Should output: "main:0.0"
```

## Implementation Location
Modify `~/.claude/hooks/notifier.sh`:
- Add context capture block early in script (after config load)
- Populate variables before constructing JSON payload
- Pass through to `terminal-notifier` via `-userInfo` JSON object
