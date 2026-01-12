# Spec: Desktop Notification Sender

## Purpose
Send macOS native notifications using `terminal-notifier` with click handler integration, enabling click-through to Ghostty terminal + tmux navigation.

## Inputs
- Notification title: string
- Notification message: string
- Event type: string ("notification", "stop", "idle-notification")
- JSON payload: object (from Spec 02)
- Notification priority/tags: strings (high/default/low)

## Outputs
- macOS Notification Center notification displayed to user
- User click triggers notification-handler.sh via `-execute` parameter
- Payload passed to handler via command-line argument

## Dependencies
- `terminal-notifier` command (macOS only; install via `brew install terminal-notifier`)
- Bash 4.0+
- `jq` for payload validation
- notification-handler.sh script at `~/.local/bin/notification-handler.sh` (Spec 04)
- Spec 01 (tmux context) and Spec 02 (payload structure)

## Key Decisions

### Decision 1: Tool Selection
Use `terminal-notifier` (not `say` or system dialogs) because:
- Supports click handlers via `-execute` parameter
- Integrates with Notification Center
- Non-blocking (doesn't freeze terminal)
- Works in SSH sessions (locally on macOS)

### Decision 2: Execute Handler
Pass JSON payload as argument to handler script: `-execute "$HOME/.local/bin/notification-handler.sh '$PAYLOAD'"`
Use single quotes inside double quotes to preserve JSON special characters.

### Decision 3: Notification Grouping
Use consistent "Subtitle" (app name) across all notifications for Notification Center grouping. Enables user to manage all Claude Code notifications together.

### Decision 4: Failure Handling
If `terminal-notifier` not found or fails, silently exit (don't crash hook). Rationale: Hook should not fail notification of idle state; missing notifier is soft failure.

## Command Format
```bash
terminal-notifier \
    -title "TITLE_TEXT" \
    -subtitle "Claude Code" \
    -message "MESSAGE_TEXT" \
    -execute "~/.local/bin/notification-handler.sh '$PAYLOAD_JSON'" \
    -sender "com.ghostty.terminal" \
    -contentImage "/path/to/icon.png" \  # optional
    2>/dev/null || true  # Suppress errors if tool not available
```

## Verification
```bash
# Check terminal-notifier installed
which terminal-notifier

# Test basic notification
terminal-notifier -title "Test" -message "Click me" -execute "echo clicked"

# Test with JSON payload
payload='{"repo_path":"/Users/vera/github/dotfiles","tmux_target":"main:0.0"}'
terminal-notifier \
    -title "Test" \
    -message "Test message" \
    -execute "~/.local/bin/notification-handler.sh '$payload'" \
    2>/dev/null

# Manually test handler invocation
~/.local/bin/notification-handler.sh '{"repo_path":"/Users/vera/github/dotfiles","tmux_target":"main:0.0"}'
```

## Implementation Location
Create new file `~/.claude/hooks/notifier-desktop.sh`:
- Function to send terminal-notifier notification
- Accept title, message, and JSON payload as arguments
- Handle missing terminal-notifier gracefully
- Called from idle-detector.sh (Spec 05) when device_type == "desktop"
