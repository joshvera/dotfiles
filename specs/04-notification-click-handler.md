# Spec: Notification Click Handler

## Purpose
Execute when user clicks desktop notification, routing to Ghostty terminal and tmux pane specified in notification payload, with graceful session recovery if tmux session no longer exists.

## Inputs
- JSON payload: string argument (from Spec 02) containing repo_path, tmux_target, tmux_session
- Ghostty AppleScript API availability (applescript branch build)
- tmux installation with existing sessions or ability to create new sessions

## Outputs
- Ghostty terminal focused (AppleScript)
- tmux pane selected (if session exists)
- OR tmux session recreated (if session missing)
- Handler exits cleanly with status 0 (even if partial success)

## Dependencies
- Ghostty (applescript branch) with AppleScript support
- `tmux` command-line tool
- `jq` for JSON parsing
- Bash 4.0+
- Script location: `~/.local/bin/notification-handler.sh`
- Spec 02 (payload structure) defines input format

## Handler Flow

1. **Parse Payload**
   - Extract `repo_path`, `tmux_target`, `tmux_session` from JSON
   - Validate extraction (exit silently if parse fails)

2. **Focus Ghostty Terminal (AppleScript)**
   - Query all terminals for working directory containing `repo_path`
   - Focus first match
   - If no match: log warning but continue (user can navigate manually)

3. **Navigate/Recover tmux Session**
   - If `tmux_target` is null: skip tmux navigation
   - If session exists: `tmux select-pane -t $TMUX_TARGET` to jump to pane
   - If session missing: recreate with `tmux new-session -d -s $TMUX_SESSION -c $REPO_PATH`
   - If recreate fails: exit silently (session recovery best-effort)

4. **Cleanup & Exit**
   - Exit 0 on completion (even partial success)
   - Log errors to syslog or file for debugging

## Key Decisions

### Decision 1: Partial Success
If either Ghostty focus or tmux navigation fails, still exit 0. Rationale: User clicked notification intending navigation; even partial success (terminal focused but pane not selected) is better than failure state. User can manually select pane.

### Decision 2: First Match for Multi-Window
If multiple Ghostty terminals have matching repo_path, focus first one. Rationale: Simple, deterministic, and most common case is single terminal per repo.

### Decision 3: Session Recovery
If tmux session missing, recreate with `new-session -d -s ... -c ...` (detached, in repo directory). Do NOT create new window in existing session; start fresh session. Rationale: Original session may have had special structure; recreating in repo dir is most useful recovery.

### Decision 4: AppleScript Error Handling
Wrap AppleScript in osascript with `||true` to suppress errors. Do not fail handler if AppleScript unavailable or fails (e.g., Ghostty not running). Rationale: Handler should be resilient; degraded mode (tmux-only navigation) acceptable.

## Implementation Detail: AppleScript Pattern
```applescript
tell application "Ghostty"
    set allTerms to terminals
    repeat with t in allTerms
        if working directory of t contains "$REPO_PATH" then
            focus in t
            exit repeat
        end if
    end repeat
end tell
```

## Verification
```bash
# Test 1: Handler with valid payload and existing session
~/.local/bin/notification-handler.sh \
  '{"repo_path":"$HOME/github/dotfiles","tmux_target":"main:0.0","tmux_session":"main"}'
# Expected: Ghostty focused, main:0.0 pane selected

# Test 2: Handler with missing session
~/.local/bin/notification-handler.sh \
  '{"repo_path":"$HOME/github/dotfiles","tmux_target":"deleted:0.0","tmux_session":"deleted"}'
# Expected: Ghostty focused, new "deleted" session created in $HOME/github/dotfiles

# Test 3: Handler with null tmux fields
~/.local/bin/notification-handler.sh \
  '{"repo_path":"$HOME/github/dotfiles","tmux_target":null,"tmux_session":null}'
# Expected: Ghostty focused, no tmux navigation

# Test 4: Handler with invalid JSON (silent failure)
~/.local/bin/notification-handler.sh 'invalid json'
# Expected: Exit 0, no errors printed

# Manual AppleScript test
osascript -e 'tell application "Ghostty" to get working directory of terminal 1'
```

## Implementation Location
Create new file `~/.local/bin/notification-handler.sh`:
- Executable bash script (chmod +x)
- Receive payload as first argument
- Implement flow steps above
- Log errors (optional, to ~/.local/log/notification-handler.log)
- Exit 0 always
