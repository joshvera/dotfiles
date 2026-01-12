# Spec: Haiku Summarization

## Purpose
Generate concise notification summaries using Claude Haiku API for response content, with context-aware fallback messages for permission requests.

## Inputs
- For Stop events: Last assistant response text from transcript (up to 4000 chars)
- For PermissionRequest events: Tool name from hook input
- `ANTHROPIC_API_KEY` environment variable (sourced from secrets)

## Outputs
- Summary string (under 100 characters) suitable for notification display
- Fallback message if API call fails or is unavailable

## Summary Generation Rules

| Event Type | Tool Name | Summary Source |
|------------|-----------|----------------|
| Stop | N/A | Haiku API summary of last response |
| PermissionRequest | AskUserQuestion | "Waiting for your answer" |
| PermissionRequest | Edit/Write/MultiEdit | "Waiting for permission: File edit" |
| PermissionRequest | Bash/BashOutput | "Waiting for permission: Run command" |
| PermissionRequest | Other | "Waiting for permission: {tool_name}" |
| Any | API failure | "Response ready" / "Waiting for input" |

## Dependencies
- `curl` for API requests
- `jq` for JSON handling
- `ANTHROPIC_API_KEY` from `~/.secrets/.secrets`
- Claude Haiku model: `claude-3-5-haiku-latest`

## Key Decisions

### Decision 1: API Timeout
Use 15-second timeout for Haiku API calls. Rationale: Notifications should not be significantly delayed; fallback to generic message is acceptable.

### Decision 2: Summary Length
Request summaries under 100 characters via prompt. Fits comfortably in macOS notification and ntfy message fields.

### Decision 3: Transcript Extraction
Extract last assistant response from transcript, not entire history. Limits context and API costs; most recent response is most relevant.

### Decision 4: Secrets Sourcing
Source `~/.secrets/.secrets` at script start if `ANTHROPIC_API_KEY` not set. Enables hook subprocess to access API credentials.

### Decision 5: Graceful Degradation
Never fail the notification due to summarization failure. Always fall back to generic message.

## Implementation

```bash
# Source secrets at script start
if [[ -z "${ANTHROPIC_API_KEY:-}" && -f "$HOME/.secrets/.secrets" ]]; then
    source "$HOME/.secrets/.secrets"
fi

get_last_response() {
    local transcript="$1"
    [[ -z "$transcript" || ! -f "$transcript" ]] && return

    grep '"role":"assistant"' "$transcript" 2>/dev/null | tail -1 | jq -r '
        .message.content | map(select(.type == "text")) | map(.text) | join("\n")
    ' 2>/dev/null | head -c 4000
}

summarize_with_haiku() {
    local text="$1"

    if [[ -z "$text" ]]; then
        echo "$(date): summarize_with_haiku: empty text" >> /tmp/claude-hook-debug.log
        return
    fi

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "$(date): summarize_with_haiku: no API key" >> /tmp/claude-hook-debug.log
        return
    fi

    local payload
    payload=$(jq -n \
        --arg text "$text" \
        '{
            model: "claude-3-5-haiku-latest",
            max_tokens: 100,
            messages: [{
                role: "user",
                content: ("Summarize in 1 brief sentence for a notification (under 100 chars):\n\n" + $text)
            }]
        }')

    local response
    response=$(curl -s --max-time 15 \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$payload" \
        "https://api.anthropic.com/v1/messages" 2>&1)

    local summary
    summary=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)

    if [[ -z "$summary" ]]; then
        echo "$(date): summarize_with_haiku: API response: $response" >> /tmp/claude-hook-debug.log
    fi

    echo "$summary"
}

get_permission_summary() {
    local tool_name="$1"

    case "$tool_name" in
        "AskUserQuestion")
            echo "Waiting for your answer"
            ;;
        "Edit"|"Write"|"MultiEdit")
            echo "Waiting for permission: File edit"
            ;;
        "Bash"|"BashOutput")
            echo "Waiting for permission: Run command"
            ;;
        *)
            if [[ -n "$tool_name" && "$tool_name" != "unknown" ]]; then
                echo "Waiting for permission: $tool_name"
            else
                echo "Waiting for input"
            fi
            ;;
    esac
}
```

## Verification
```bash
# Test Haiku summarization
export ANTHROPIC_API_KEY="your-key"
summary=$(summarize_with_haiku "Claude has finished implementing the notification feature and is waiting for you to test it.")
echo "Summary: $summary"
# Expected: Short summary under 100 chars

# Test permission summary
get_permission_summary "AskUserQuestion"
# Expected: "Waiting for your answer"

get_permission_summary "Bash"
# Expected: "Waiting for permission: Run command"

# Test fallback (no API key)
unset ANTHROPIC_API_KEY
summary=$(summarize_with_haiku "Some text")
echo "Summary: ${summary:-EMPTY}"
# Expected: EMPTY (graceful failure)
```

## Implementation Location
Functions already exist in `~/.claude/hooks/idle-detector.sh`:
- `get_last_response()` - transcript extraction
- `summarize_with_haiku()` - API call
- Add `get_permission_summary()` - context-aware fallback
