# Claude Code Hooks

Hooks in `.claude/hooks/` run automatically in response to Claude Code lifecycle events. They are symlinked to `~/.claude/hooks/` by `scripts/bootstrap-core.sh`.

## Active Hook Wiring

Configured in `.claude/settings.json`:

| Event | Command | Purpose |
|---|---|---|
| **Stop** | `idle-detector.sh claude-finished` | Start idle monitoring after Claude responds |
| **UserPromptSubmit** | `idle-detector.sh user-activity` | Cancel idle timer when user sends input |
| **PermissionRequest** | `idle-detector.sh permission-request` | Notify user when Claude needs permission |

## Hook Inventory

### Notification System

**idle-detector.sh** - Core idle detection and notification orchestrator. Monitors Claude's response lifecycle, tracks user activity, and sends push notifications via ntfy when Claude has been waiting for input. Manages background timer processes, session state in `/tmp/claude-notification-state-{session}/`, and coordinates with the notifier scripts. Configurable idle timeout via `CLAUDE_IDLE_TIMEOUT` (default: 30s).

**notifier.sh** - Full-featured ntfy notification sender. Detects terminal context (tmux window name, iTerm/Terminal title, X11/Wayland window title) and includes it in notifications. Supports rate limiting (one per 2s), retry logic (2 attempts), and priority escalation for error keywords. Events: `notification`, `stop`, `idle-notification`.

**notifier-simple.sh** - Lightweight alternative to notifier.sh. Same ntfy integration without retries, rate limiting, or terminal detection. Good for environments where the full notifier is overkill.

**manual-notifier.sh** - Manual test script for verifying ntfy connectivity. Run directly to confirm your topic and server config work.

**response-complete.sh** - Thin wrapper that calls `idle-detector.sh claude-finished`. Used as an alternative entry point for the Stop event.

### Configuration

Notification scripts read ntfy config from (checked in order):
1. `~/.config/claude-native/ntfy.json`
2. `~/.config/claudetainer/ntfy.json`

Format:
```json
{"ntfy_topic": "your-topic-name", "ntfy_server": "https://ntfy.sh"}
```

Set `CLAUDE_HOOKS_NTFY_ENABLED=false` to disable notifications globally.

### TDD Guard

**tdd-guard.sh** - Enforces test-driven development by blocking Write/Edit/MultiEdit on production files unless failing tests exist. Only active in projects with a `.claude/tdd-guard/` directory. Supports:
- **Python/JS/PHP**: Uses `tdd-guard check` CLI
- **Swift**: Looks for `XCTFail("TDD: ...")` markers via custom reporter
- **Rust**: Looks for `panic!("TDD: ...")` markers via custom reporter

### Utilities

**hello.sh** - Test hook that prints a message. Useful for verifying hook execution works.

**lib/session.sh** - Shared library providing `get_session_id()` for consistent session identification across hooks.

## Setup

Hooks are symlinked automatically by bootstrap:

```bash
scripts/bootstrap-core.sh
```

Or manually:

```bash
ln -sfn ~/github/dotfiles/.claude/hooks ~/.claude/hooks
```
