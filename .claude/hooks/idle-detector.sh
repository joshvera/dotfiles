#!/usr/bin/env bash

# Custom idle detection for Claude Code in SSH/Zellij environments
# This creates a background process that monitors for idle state and sends notifications

set -euo pipefail

# Source secrets if API key not already set (needed for Haiku summarization)
if [[ -z "${ANTHROPIC_API_KEY:-}" && -f "$HOME/.secrets/.secrets" ]]; then
    source "$HOME/.secrets/.secrets"
fi

IDLE_TIMEOUT=${CLAUDE_IDLE_TIMEOUT:-30} # Default 30 seconds (configurable)
IDLE_STATE_FILE="/tmp/claude-idle-state-$(basename "$(pwd)")"
IDLE_DETECTOR_PID_FILE="/tmp/claude-idle-detector-$(basename "$(pwd)").pid"

# Generate unique session ID for notification state isolation
# Format: hostname:session:pane_id
# Returns: Session ID string for use in state directory naming
get_session_id() {
    local hostname
    hostname=$(hostname -s)

    # Tmux: use session name and pane ID for pane-level isolation
    if [[ -n "${TMUX:-}" ]]; then
        local session pane_id
        session=$(tmux display-message -p '#S' 2>/dev/null || echo "tmux")
        pane_id=$(tmux display-message -p '#D' 2>/dev/null || echo "0")
        # Remove leading % from pane_id if present
        pane_id="${pane_id#%}"
        echo "${hostname}:${session}:${pane_id}"
        return
    fi

    # Zellij: use session name (Zellij doesn't expose pane ID as easily)
    if [[ -n "${ZELLIJ:-}" || -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        local session="${ZELLIJ_SESSION_NAME:-zellij}"
        echo "${hostname}:${session}:0"
        return
    fi

    # Fallback: hash of terminal device and PID for uniqueness
    local term_device="${TTY:-notty}"
    local hash
    hash=$(echo "${hostname}:${term_device}:$$" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$$")
    echo "${hostname}:shell:${hash:0:8}"
}

# Initialize state directory structure for notification system
# Creates: /tmp/claude-notification-state-${SESSION_ID}/timers/
# Returns: 0 on success
initialize_state_dir() {
    local session_id
    session_id=$(get_session_id)

    local state_dir="/tmp/claude-notification-state-${session_id}"
    local timers_dir="${state_dir}/timers"

    # Create state directory if it doesn't exist
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir" || {
            echo "$(date): Failed to create state directory: $state_dir" >> /tmp/claude-hook-debug.log
            return 1
        }
    fi

    # Create timers subdirectory
    if [[ ! -d "$timers_dir" ]]; then
        mkdir -p "$timers_dir" || {
            echo "$(date): Failed to create timers directory: $timers_dir" >> /tmp/claude-hook-debug.log
            return 1
        }
    fi

    echo "$state_dir"
}

# Generate unique event ID for notification lifecycle tracking
# Uses uuidgen if available, otherwise falls back to timestamp+random
# Returns: Event ID string (UUID4 or timestamp-based)
generate_event_id() {
    if command -v uuidgen > /dev/null 2>&1; then
        # Prefer uuidgen for true UUID4
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback: timestamp + random number
        local timestamp
        timestamp=$(date +%s%N 2>/dev/null || date +%s)
        local random_part
        random_part=$(( RANDOM * RANDOM ))
        echo "${timestamp}-${random_part}"
    fi
}

# Get human-readable permission summary for a tool
# Usage: get_permission_summary TOOL_NAME
# Returns: Human-readable string describing what permission is being requested
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
            fi
            ;;
    esac
}

# Create JSON metadata file for an event
# Usage: record_event_metadata EVENT_ID EVENT_TYPE [SUMMARY]
# Creates: ${STATE_DIR}/${EVENT_ID}.json with standardized fields
record_event_metadata() {
    local event_id="$1"
    local event_type="$2"
    local summary="${3:-}"

    if [[ -z "$event_id" || -z "$event_type" ]]; then
        echo "$(date): record_event_metadata: missing event_id or event_type" >> /tmp/claude-hook-debug.log
        return 1
    fi

    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    local session_id
    session_id=$(get_session_id)

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local metadata_file="${state_dir}/${event_id}.json"

    # Build JSON using jq for proper escaping
    jq -n \
        --arg event_id "$event_id" \
        --arg event_type "$event_type" \
        --arg timestamp "$timestamp" \
        --arg session_id "$session_id" \
        --arg summary "$summary" \
        '{
            event_id: $event_id,
            event_type: $event_type,
            timestamp: $timestamp,
            session_id: $session_id,
            summary: $summary,
            flags: {}
        }' > "$metadata_file" || {
        echo "$(date): Failed to create metadata file: $metadata_file" >> /tmp/claude-hook-debug.log
        return 1
    }

    echo "$(date): Created event metadata: $metadata_file" >> /tmp/claude-hook-debug.log
    echo "$metadata_file"
}

# Atomically update a single field in event metadata
# Usage: update_event_field EVENT_ID FIELD_NAME FIELD_VALUE
# Updates the JSON file in place using jq
update_event_field() {
    local event_id="$1"
    local field_name="$2"
    local field_value="$3"

    if [[ -z "$event_id" || -z "$field_name" ]]; then
        echo "$(date): update_event_field: missing event_id or field_name" >> /tmp/claude-hook-debug.log
        return 1
    fi

    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    local metadata_file="${state_dir}/${event_id}.json"

    if [[ ! -f "$metadata_file" ]]; then
        echo "$(date): update_event_field: metadata file not found: $metadata_file" >> /tmp/claude-hook-debug.log
        return 1
    fi

    # Create temp file for atomic update
    local temp_file="${metadata_file}.tmp"

    # Update field using jq (handle both top-level and flags.* fields)
    if [[ "$field_name" == flags.* ]]; then
        # Update nested flag field
        local flag_key="${field_name#flags.}"
        jq --arg key "$flag_key" --arg value "$field_value" \
            '.flags[$key] = ($value | if . == "true" then true elif . == "false" then false else . end)' \
            "$metadata_file" > "$temp_file" || {
            rm -f "$temp_file"
            echo "$(date): update_event_field: jq failed for $field_name" >> /tmp/claude-hook-debug.log
            return 1
        }
    else
        # Update top-level field
        jq --arg key "$field_name" --arg value "$field_value" \
            '.[$key] = $value' \
            "$metadata_file" > "$temp_file" || {
            rm -f "$temp_file"
            echo "$(date): update_event_field: jq failed for $field_name" >> /tmp/claude-hook-debug.log
            return 1
        }
    fi

    # Atomic move
    mv "$temp_file" "$metadata_file" || {
        rm -f "$temp_file"
        echo "$(date): update_event_field: failed to move temp file" >> /tmp/claude-hook-debug.log
        return 1
    }

    echo "$(date): Updated event field: $event_id.$field_name = $field_value" >> /tmp/claude-hook-debug.log
}

# Mark all previous events in the session as superseded
# Usage: mark_events_superseded CURRENT_EVENT_ID
# Sets flags.superseded=true on all other .json files in STATE_DIR
mark_events_superseded() {
    local current_event_id="$1"

    if [[ -z "$current_event_id" ]]; then
        echo "$(date): mark_events_superseded: missing current_event_id" >> /tmp/claude-hook-debug.log
        return 1
    fi

    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    # Find all JSON files except the current one
    local count=0
    for metadata_file in "$state_dir"/*.json; do
        [[ ! -f "$metadata_file" ]] && continue

        local basename
        basename=$(basename "$metadata_file" .json)

        # Skip current event
        [[ "$basename" == "$current_event_id" ]] && continue

        # Mark as superseded
        update_event_field "$basename" "flags.superseded" "true"
        count=$((count + 1))
    done

    echo "$(date): Marked $count events as superseded" >> /tmp/claude-hook-debug.log
}

# Kill all pending timer processes and remove timer files
# Usage: kill_pending_timers
# Iterates over timers/*.timer files, kills PIDs, removes files
# Handles empty directory and already-dead processes gracefully
kill_pending_timers() {
    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    local timers_dir="${state_dir}/timers"

    # Handle empty timers directory gracefully
    if [[ ! -d "$timers_dir" ]]; then
        echo "$(date): kill_pending_timers: timers directory not found" >> /tmp/claude-hook-debug.log
        return 0
    fi

    local count=0
    for timer_file in "$timers_dir"/*.timer; do
        # Skip if no timer files exist (glob doesn't match)
        [[ ! -f "$timer_file" ]] && continue

        # Read PID from timer file
        local pid
        pid=$(cat "$timer_file" 2>/dev/null)

        if [[ -n "$pid" ]]; then
            # Check if process exists before killing
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null && {
                    echo "$(date): Killed timer process: $pid" >> /tmp/claude-hook-debug.log
                    count=$((count + 1))
                }
            else
                echo "$(date): Timer process already dead: $pid" >> /tmp/claude-hook-debug.log
            fi
        fi

        # Remove timer file regardless of whether process was alive
        rm -f "$timer_file"
    done

    echo "$(date): Cleaned up $count active timer(s)" >> /tmp/claude-hook-debug.log
}

# Detect device type: desktop (local) vs mobile (SSH/mosh)
detect_device_type() {
    # Explicit override
    if [[ -n "${CLAUDE_NOTIFY_MODE:-}" ]]; then
        echo "$CLAUDE_NOTIFY_MODE"
        return
    fi

    # SSH = mobile (from Blink)
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        echo "mobile"
        return
    fi

    # Mosh = mobile (check env var first, then process tree)
    if [[ -n "${MOSH_CONNECTION:-}" ]]; then
        echo "mobile"
        return
    fi

    # Check if mosh-server is an ancestor process (portable method)
    local pid=$$
    while [[ $pid -ne 1 ]]; do
        local pname
        pname=$(ps -p "$pid" -o comm= 2>/dev/null) || break
        if [[ "$pname" == *mosh-server* ]]; then
            echo "mobile"
            return
        fi
        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ') || break
    done

    # Local = desktop
    echo "desktop"
}

# File to store transcript path for background worker
TRANSCRIPT_PATH_FILE="/tmp/claude-transcript-path-$(basename "$(pwd)")"

# File to store permission context (tool name) for notification message
PERMISSION_CONTEXT_FILE="/tmp/claude-permission-context-$(basename "$(pwd)")"

# Extract last assistant response from transcript
get_last_response() {
    local transcript="$1"
    [[ -z "$transcript" || ! -f "$transcript" ]] && return

    grep '"role":"assistant"' "$transcript" 2>/dev/null | tail -1 | jq -r '
        .message.content | map(select(.type == "text")) | map(.text) | join("\n")
    ' 2>/dev/null | head -c 4000
}

# Summarize response with Claude Haiku
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

    # Build JSON payload using jq for proper escaping
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

# Function to send idle notification via ntfy
# Usage: send_idle_notification [summary]
send_idle_notification() {
    local summary="${1:-}"

    # Use env vars consistent with zsh notify function
    local ntfy_url="${NTFY_URL:-}"
    local ntfy_topic="${NTFY_TOPIC:-}"

    if [[ -z "$ntfy_url" ]]; then
        return 0  # No ntfy configured
    fi

    local cwd_basename
    cwd_basename=$(basename "$(pwd)")
    local title="Claude Code: $cwd_basename"
    local session_info=""
    if [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        local hostname
        hostname=$(hostname)
        session_info=" → ${hostname}:${ZELLIJ_SESSION_NAME}"
    elif [[ -n "${TMUX:-}" ]]; then
        local hostname
        hostname=$(hostname)
        local tmux_session
        tmux_session=$(tmux display-message -p '#S' 2>/dev/null || echo "tmux")
        session_info=" → ${hostname}:${tmux_session}"
    fi

    local message
    if [[ -n "$summary" ]]; then
        message="${summary}${session_info}"
    else
        message="Waiting for input (idle >${IDLE_TIMEOUT}s)${session_info}"
    fi
    local tags="claude-code,idle,custom"

    # Build Blink deep link - simplified to just open the app
    local click_action=""
    if [[ -n "${SSH_CONNECTION:-}" && -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        # Simple approach: just open Blink Shell app
        click_action="blinkshell://"

        # TODO: For session-specific targeting, configure SSH aliases in Blink:
        # See blink-ssh-config.txt for the full setup with RemoteCommand
        # Then use: click_action="ssh://dev-${ZELLIJ_SESSION_NAME}"
    fi

    # Send notification with optional click action
    if [[ -n "$click_action" ]]; then
        curl -s --max-time 5 \
            -H "Title: $title" \
            -H "Tags: $tags" \
            -H "Click: $click_action" \
            -H "Actions: view, Open Blink, $click_action" \
            -d "$message" \
            "$ntfy_url/$ntfy_topic" > /dev/null 2>&1 || true
    else
        curl -s --max-time 5 \
            -H "Title: $title" \
            -H "Tags: $tags" \
            -d "$message" \
            "$ntfy_url/$ntfy_topic" > /dev/null 2>&1 || true
    fi
}

# Function to send desktop notification (macOS - immediate)
send_desktop_notification() {
    local title="Claude Code: $(basename "$(pwd)")"
    local message="Response ready"

    # No sound per user preference
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Function to send desktop notification with reaction detection
# Usage: send_desktop_notification_with_reaction TITLE MESSAGE EVENT_ID
# Sends immediate desktop notification, then spawns detached background process
# that waits 2 seconds and creates cancel marker + updates metadata
send_desktop_notification_with_reaction() {
    local title="$1"
    local message="$2"
    local event_id="$3"

    if [[ -z "$title" || -z "$message" || -z "$event_id" ]]; then
        echo "$(date): send_desktop_notification_with_reaction: missing required parameters" >> /tmp/claude-hook-debug.log
        return 1
    fi

    # Send immediate desktop notification
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true

    # Get state directory for cancel marker
    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    # Spawn fully detached background process to detect reaction
    # After 2 seconds, assume user saw notification and create cancel marker
    (
        sleep 2
        # Create cancel marker
        touch "${state_dir}/.cancel-${event_id}"
        # Update metadata with desktop_reacted flag
        update_event_field "${event_id}" "flags.desktop_reacted" "true"
    ) &>/dev/null &
    disown

    echo "$(date): Desktop notification sent with reaction detection for event: $event_id" >> /tmp/claude-hook-debug.log
}

# Schedule mobile notification timer (30 second delay)
# Usage: schedule_mobile_notification EVENT_ID MESSAGE
# Creates detached background process that sleeps 30s, checks for cancel marker,
# then sends ntfy notification if not cancelled or superseded
schedule_mobile_notification() {
    local event_id="$1"
    local message="$2"

    if [[ -z "$event_id" || -z "$message" ]]; then
        echo "$(date): schedule_mobile_notification: missing event_id or message" >> /tmp/claude-hook-debug.log
        return 1
    fi

    # Get state directory for cancel marker and timer file
    local state_dir
    state_dir=$(initialize_state_dir) || return 1

    local timers_dir="${state_dir}/timers"
    local timer_file="${timers_dir}/${event_id}.timer"
    local cancel_marker="${state_dir}/.cancel-${event_id}"
    local metadata_file="${state_dir}/${event_id}.json"

    # Spawn fully detached background process for delayed notification
    # Pattern: same as send_desktop_notification_with_reaction()
    (
        # Sleep 30 seconds (configurable for testing via TEST_MOBILE_DELAY)
        local delay="${TEST_MOBILE_DELAY:-30}"
        sleep "$delay"

        # Check for cancel marker
        if [[ -f "$cancel_marker" ]]; then
            echo "$(date): Mobile notification cancelled via marker: $event_id" >> /tmp/claude-hook-debug.log
            rm -f "$timer_file"
            return 0
        fi

        # Check if event was superseded by reading metadata
        if [[ -f "$metadata_file" ]]; then
            local superseded
            superseded=$(jq -r '.flags.superseded // false' "$metadata_file" 2>/dev/null)
            if [[ "$superseded" == "true" ]]; then
                echo "$(date): Mobile notification cancelled (superseded): $event_id" >> /tmp/claude-hook-debug.log
                rm -f "$timer_file"
                return 0
            fi
        fi

        # Send ntfy notification
        echo "$(date): Sending mobile notification for event: $event_id" >> /tmp/claude-hook-debug.log
        send_idle_notification "$message"

        # Clean up timer file
        rm -f "$timer_file"
    ) &>/dev/null &

    # Capture PID and store it
    local timer_pid=$!

    # Store PID in timer file for cleanup
    echo "$timer_pid" > "$timer_file"

    disown "$timer_pid" 2>/dev/null || true

    echo "$(date): Mobile notification scheduled (PID: $timer_pid, event: $event_id)" >> /tmp/claude-hook-debug.log
}

# Function to start idle monitoring
start_idle_monitor() {
    # Kill existing monitor for this project
    if [[ -f "$IDLE_DETECTOR_PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$IDLE_DETECTOR_PID_FILE" 2> /dev/null || echo "")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2> /dev/null; then
            kill "$old_pid" 2> /dev/null || true
        fi
        rm -f "$IDLE_DETECTOR_PID_FILE"
    fi

    # Start background monitor - fully detached to prevent blocking Claude
    local log_file="/tmp/claude-idle-monitor.log"

    # Disable job control to avoid implicit waits
    set +m

    # Start fully detached worker with closed stdio - embed the notification function
    if command -v setsid > /dev/null 2>&1; then
        setsid bash -c "
            exec </dev/null >>\"$log_file\" 2>&1
            
            timeout_val=$IDLE_TIMEOUT
            state_file=\"$IDLE_STATE_FILE\"
            
            echo \"[\$(date)] DEBUG: Monitor vars - timeout=\${timeout_val}, file=\$state_file\"
            echo \"[\$(date)] DEBUG: Working dir: \$(pwd)\"
            echo \"[\$(date)] DEBUG: Files in /tmp: \$(ls -la /tmp/claude-idle-state-* 2>/dev/null || echo 'None found')\"
            
            echo \"[\$(date)] Monitor started: timeout=\${timeout_val}s, file=\$state_file\"
            
            sleep \"\$timeout_val\"
            
            echo \"[\$(date)] DEBUG: After sleep, checking file: \$state_file\"
            echo \"[\$(date)] DEBUG: File test result: \$(ls -la \"\$state_file\" 2>/dev/null || echo 'File not found')\"
            
            if [[ -f \"\$state_file\" ]]; then
                last_activity=\$(stat -f %m \"\$state_file\" 2>/dev/null || echo \"0\")
                current_time=\$(date +%s)
                time_diff=\$((current_time - last_activity))
                
                echo \"[\$(date)] File age: \${time_diff}s, threshold: \$timeout_val\"
                
                if [[ \$time_diff -ge \$timeout_val ]]; then
                    echo \"[\$(date)] Sending notification\"
                    
                    # Call the original script to send notification with summary
                    \"$0\" notify-with-summary
                    rm -f \"\$state_file\"
                fi
            else
                echo \"[\$(date)] No idle state file found\"
            fi
        " &
        worker_pid=$!
    else
        nohup bash -c "
            exec </dev/null >>\"$log_file\" 2>&1
            
            timeout_val=$IDLE_TIMEOUT
            state_file=\"$IDLE_STATE_FILE\"
            
            echo \"[\$(date)] DEBUG: Monitor vars - timeout=\${timeout_val}, file=\$state_file\"
            echo \"[\$(date)] DEBUG: Working dir: \$(pwd)\"
            echo \"[\$(date)] DEBUG: Files in /tmp: \$(ls -la /tmp/claude-idle-state-* 2>/dev/null || echo 'None found')\"
            
            echo \"[\$(date)] Monitor started (nohup): timeout=\${timeout_val}s, file=\$state_file\"
            
            sleep \"\$timeout_val\"
            
            echo \"[\$(date)] DEBUG: After sleep, checking file: \$state_file\"
            echo \"[\$(date)] DEBUG: File test result: \$(ls -la \"\$state_file\" 2>/dev/null || echo 'File not found')\"
            
            if [[ -f \"\$state_file\" ]]; then
                last_activity=\$(stat -f %m \"\$state_file\" 2>/dev/null || echo \"0\")
                current_time=\$(date +%s)
                time_diff=\$((current_time - last_activity))
                
                echo \"[\$(date)] File age: \${time_diff}s, threshold: \$timeout_val\"
                
                if [[ \$time_diff -ge \$timeout_val ]]; then
                    echo \"[\$(date)] Sending notification\"
                    
                    # Call the original script to send notification with summary
                    \"$0\" notify-with-summary
                    rm -f \"\$state_file\"
                fi
            else
                echo \"[\$(date)] No idle state file found\"
            fi
        " &
        worker_pid=$!
    fi

    echo "$worker_pid" > "$IDLE_DETECTOR_PID_FILE"
    disown "$worker_pid" 2> /dev/null || true
}

# Function to mark activity (Claude finished responding)
# Implements full event lifecycle with desktop notification and mobile scheduler
mark_claude_finished() {
    local device_type
    device_type=$(detect_device_type)

    # Read hook input from stdin (contains transcript_path)
    local hook_input=""
    if [[ ! -t 0 ]]; then
        hook_input=$(cat)
    fi

    # Extract transcript path
    local transcript_path
    transcript_path=$(echo "$hook_input" | jq -r '.transcript_path // empty' 2>/dev/null)

    echo "$(date): Stop hook triggered - Claude finished (device: $device_type, transcript: ${transcript_path:-none})" >> /tmp/claude-hook-debug.log

    # Initialize state directory and generate unique event ID
    local state_dir
    state_dir=$(initialize_state_dir) || {
        echo "$(date): Failed to initialize state directory" >> /tmp/claude-hook-debug.log
        return 1
    }

    local event_id
    event_id=$(generate_event_id)
    echo "$(date): Generated event ID: $event_id" >> /tmp/claude-hook-debug.log

    # Kill any pending timers from previous events
    kill_pending_timers

    # Mark all previous events in this session as superseded
    mark_events_superseded "$event_id"

    # Extract transcript and generate summary using Haiku
    local summary=""
    if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
        local response
        response=$(get_last_response "$transcript_path")
        if [[ -n "$response" ]]; then
            summary=$(summarize_with_haiku "$response")
            echo "$(date): Generated summary: $summary" >> /tmp/claude-hook-debug.log
        fi
    fi

    # Use default message if no summary available
    if [[ -z "$summary" ]]; then
        summary="Response ready"
    fi

    # Record event metadata
    record_event_metadata "$event_id" "stop" "$summary" || {
        echo "$(date): Failed to record event metadata" >> /tmp/claude-hook-debug.log
        return 1
    }

    # Send desktop notification with reaction detection (immediate)
    local cwd_basename
    cwd_basename=$(basename "$(pwd)")
    local title="Claude Code: $cwd_basename"
    send_desktop_notification_with_reaction "$title" "$summary" "$event_id"

    # Schedule mobile notification (30 second delay)
    schedule_mobile_notification "$event_id" "$summary"

    echo "$(date): Stop hook complete - event: $event_id, desktop notified, mobile scheduled" >> /tmp/claude-hook-debug.log
}

# Handle permission request from Claude
# Implements full event lifecycle with permission-aware message
on_permission_request() {
    local device_type
    device_type=$(detect_device_type)

    # Read hook input from stdin (contains tool_name)
    local hook_input=""
    if [[ ! -t 0 ]]; then
        hook_input=$(cat)
    fi

    # Extract tool name for permission context
    local tool_name
    tool_name=$(echo "$hook_input" | jq -r '.tool_name // "unknown"' 2>/dev/null)

    echo "$(date): PermissionRequest hook triggered - tool: $tool_name (device: $device_type)" >> /tmp/claude-hook-debug.log

    # Initialize state directory and generate unique event ID
    local state_dir
    state_dir=$(initialize_state_dir) || {
        echo "$(date): Failed to initialize state directory" >> /tmp/claude-hook-debug.log
        return 1
    }

    local event_id
    event_id=$(generate_event_id)
    echo "$(date): Generated event ID: $event_id" >> /tmp/claude-hook-debug.log

    # Kill any pending timers from previous events
    kill_pending_timers

    # Mark all previous events in this session as superseded
    mark_events_superseded "$event_id"

    # Generate permission-aware message using get_permission_summary
    local message
    message=$(get_permission_summary "$tool_name")

    # Use generic message if get_permission_summary returns empty
    if [[ -z "$message" ]]; then
        message="Waiting for permission"
    fi

    echo "$(date): Permission message: $message" >> /tmp/claude-hook-debug.log

    # Record event metadata
    record_event_metadata "$event_id" "permission_request" "$message" || {
        echo "$(date): Failed to record event metadata" >> /tmp/claude-hook-debug.log
        return 1
    }

    # Send desktop notification with reaction detection (immediate)
    local cwd_basename
    cwd_basename=$(basename "$(pwd)")
    local title="Claude Code: $cwd_basename"
    send_desktop_notification_with_reaction "$title" "$message" "$event_id"

    # Schedule mobile notification (30 second delay)
    schedule_mobile_notification "$event_id" "$message"

    echo "$(date): PermissionRequest hook complete - event: $event_id, desktop notified, mobile scheduled" >> /tmp/claude-hook-debug.log
}

# Handle user activity: cancel all pending notifications and clear state
# Usage: on_user_activity
# Kills all pending timer processes via kill_pending_timers()
# Creates cancel markers for all active (non-superseded) events
# Clears legacy state files for backward compatibility
# Handles missing state directory gracefully (no errors if absent)
on_user_activity() {
    echo "$(date): User activity detected" >> /tmp/claude-hook-debug.log

    # Kill all pending mobile notification timers
    kill_pending_timers

    # Create cancel markers for all active events (not yet superseded)
    # Gracefully handle missing state directory
    local state_dir
    state_dir=$(initialize_state_dir 2>/dev/null) || true

    if [[ -n "$state_dir" && -d "$state_dir" ]]; then
        local count=0
        for metadata_file in "$state_dir"/*.json; do
            # Skip if no JSON files exist (glob doesn't match)
            [[ ! -f "$metadata_file" ]] && continue

            # Check if event is superseded
            local superseded
            superseded=$(jq -r '.flags.superseded // false' "$metadata_file" 2>/dev/null)

            # Only create cancel marker for active (non-superseded) events
            if [[ "$superseded" != "true" ]]; then
                local basename
                basename=$(basename "$metadata_file" .json)
                local cancel_marker="${state_dir}/.cancel-${basename}"

                # Create cancel marker if it doesn't exist
                if [[ ! -f "$cancel_marker" ]]; then
                    touch "$cancel_marker"
                    count=$((count + 1))
                    echo "$(date): Created cancel marker for event: $basename" >> /tmp/claude-hook-debug.log
                fi
            fi
        done

        echo "$(date): Created $count cancel marker(s)" >> /tmp/claude-hook-debug.log
    fi

    # Clear legacy state files for backward compatibility
    rm -f "$IDLE_STATE_FILE"
    if [[ -f "$IDLE_DETECTOR_PID_FILE" ]]; then
        local pid
        pid=$(cat "$IDLE_DETECTOR_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$IDLE_DETECTOR_PID_FILE"
    fi
}

# Legacy function for backward compatibility
# Calls on_user_activity() to stop idle monitoring
stop_idle_monitor() {
    on_user_activity
}

# Main logic based on arguments
case "${1:-start}" in
    "claude-finished")
        mark_claude_finished
        ;;
    "user-activity")
        stop_idle_monitor
        rm -f "$PERMISSION_CONTEXT_FILE"  # Clear permission context on user input
        ;;
    "stop")
        stop_idle_monitor
        ;;
    "permission-request")
        # PermissionRequest hook - fires for both permission dialogs AND AskUserQuestion
        on_permission_request
        ;;
    "test")
        send_idle_notification
        ;;
    "notify-with-summary")
        # Read transcript, generate summary, send notification
        summary=""
        permission_context=""

        # Check for permission context (AskUserQuestion, Edit, Write, etc.)
        if [[ -f "$PERMISSION_CONTEXT_FILE" ]]; then
            permission_context=$(cat "$PERMISSION_CONTEXT_FILE" 2>/dev/null)
            rm -f "$PERMISSION_CONTEXT_FILE"

            # Generate context-aware message using get_permission_summary
            summary=$(get_permission_summary "$permission_context")
            echo "$(date): Permission context: $permission_context -> $summary" >> /tmp/claude-hook-debug.log
        fi

        # If no permission context, try transcript summarization (for Stop hook)
        if [[ -z "$summary" && -f "$TRANSCRIPT_PATH_FILE" ]]; then
            transcript_path=$(cat "$TRANSCRIPT_PATH_FILE" 2>/dev/null)
            if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
                response=$(get_last_response "$transcript_path")
                if [[ -n "$response" ]]; then
                    summary=$(summarize_with_haiku "$response")
                    echo "$(date): Generated summary: $summary" >> /tmp/claude-hook-debug.log
                fi
            fi
            rm -f "$TRANSCRIPT_PATH_FILE"
        fi

        send_idle_notification "$summary"
        ;;
    "test-detect")
        echo "Device type: $(detect_device_type)"
        ;;
    "test-desktop")
        send_desktop_notification
        ;;
    "test-summary")
        # Test summary generation with sample text
        test_text="${2:-Claude has finished implementing the notification feature and is waiting for you to test it.}"
        summary=$(summarize_with_haiku "$test_text")
        echo "Summary: $summary"
        send_idle_notification "$summary"
        ;;
    "test-permission")
        # Test permission notification (simulates PermissionRequest hook)
        tool_name="${2:-AskUserQuestion}"
        echo "$tool_name" > "$PERMISSION_CONTEXT_FILE"
        echo "Testing permission notification for: $tool_name"
        # Directly call notify-with-summary to test
        "$0" notify-with-summary
        ;;
    "test-session-id")
        # Test session ID generation
        session_id=$(get_session_id)
        echo "Session ID: $session_id"
        ;;
    "test-state-dir")
        # Test state directory initialization
        state_dir=$(initialize_state_dir)
        if [[ $? -eq 0 ]]; then
            echo "State directory created: $state_dir"
            ls -la "$state_dir"
        else
            echo "Failed to create state directory"
            exit 1
        fi
        ;;
    "test-event-id")
        # Test event ID generation
        event_id=$(generate_event_id)
        echo "Generated event ID: $event_id"
        ;;
    "test-metadata")
        # Test event metadata creation and updates
        echo "Testing event metadata system..."

        # Generate event ID
        event_id=$(generate_event_id)
        echo "Event ID: $event_id"

        # Create metadata
        metadata_file=$(record_event_metadata "$event_id" "stop" "Test summary message")
        echo "Created: $metadata_file"
        echo "Contents:"
        cat "$metadata_file" | jq .

        # Update a field
        echo -e "\nUpdating summary field..."
        update_event_field "$event_id" "summary" "Updated summary"
        echo "After update:"
        cat "$metadata_file" | jq .summary

        # Update a flag
        echo -e "\nUpdating flags.desktop_reacted flag..."
        update_event_field "$event_id" "flags.desktop_reacted" "true"
        echo "After flag update:"
        cat "$metadata_file" | jq .flags

        # Create a second event and test supersession
        echo -e "\nCreating second event to test supersession..."
        event_id2=$(generate_event_id)
        metadata_file2=$(record_event_metadata "$event_id2" "permission" "Second event")
        echo "Created: $metadata_file2"

        # Mark first event as superseded
        echo -e "\nMarking previous events as superseded..."
        mark_events_superseded "$event_id2"
        echo "First event after superseding:"
        cat "$metadata_file" | jq .flags.superseded

        echo -e "\nTest complete. State directory:"
        state_dir=$(initialize_state_dir)
        ls -la "$state_dir"
        ;;
    "test-permission-summary")
        # Test permission summary function
        echo "Testing get_permission_summary function..."
        echo ""
        echo "AskUserQuestion: $(get_permission_summary 'AskUserQuestion')"
        echo "Edit: $(get_permission_summary 'Edit')"
        echo "Write: $(get_permission_summary 'Write')"
        echo "MultiEdit: $(get_permission_summary 'MultiEdit')"
        echo "Bash: $(get_permission_summary 'Bash')"
        echo "BashOutput: $(get_permission_summary 'BashOutput')"
        echo "WebFetch: $(get_permission_summary 'WebFetch')"
        echo "Read: $(get_permission_summary 'Read')"
        echo "unknown: $(get_permission_summary 'unknown')"
        echo "empty: $(get_permission_summary '')"
        ;;
    "test-timer-cleanup")
        # Test timer cleanup function
        echo "Testing kill_pending_timers function..."

        # Get state directory
        state_dir=$(initialize_state_dir)
        timers_dir="${state_dir}/timers"
        echo "State directory: $state_dir"
        echo "Timers directory: $timers_dir"

        # Create some dummy timer files with mock PIDs
        echo "Creating test timer files..."
        echo "99999" > "$timers_dir/test-event-1.timer"
        echo "99998" > "$timers_dir/test-event-2.timer"

        # Create one timer with a real (but harmless) background process
        sleep 300 &
        real_pid=$!
        echo "$real_pid" > "$timers_dir/test-event-real.timer"
        echo "Created real timer with PID: $real_pid"

        echo -e "\nTimer files before cleanup:"
        ls -la "$timers_dir"/*.timer 2>/dev/null || echo "No timer files"

        echo -e "\nRunning kill_pending_timers..."
        kill_pending_timers

        echo -e "\nTimer files after cleanup:"
        ls -la "$timers_dir"/*.timer 2>/dev/null || echo "No timer files (cleanup successful)"

        echo -e "\nTest with empty timers directory..."
        kill_pending_timers
        echo "Empty directory test passed (no errors)"

        echo -e "\nTest complete. Check debug log:"
        tail -n 10 /tmp/claude-hook-debug.log
        ;;
    "test-desktop-reaction")
        # Test desktop notification with reaction detection
        echo "Testing send_desktop_notification_with_reaction function..."

        # Initialize state
        state_dir=$(initialize_state_dir)
        echo "State directory: $state_dir"

        # Generate event ID
        event_id=$(generate_event_id)
        echo "Event ID: $event_id"

        # Record metadata
        echo "Creating event metadata..."
        metadata_file=$(record_event_metadata "$event_id" "test" "Test desktop notification with reaction")
        echo "Metadata file: $metadata_file"
        echo "Initial metadata:"
        cat "$metadata_file" | jq .

        # Send desktop notification with reaction detection
        echo -e "\nSending desktop notification..."
        send_desktop_notification_with_reaction "Claude Code: Test" "Testing reaction detection" "$event_id"

        # Wait 3 seconds for background process to complete
        echo "Waiting 3 seconds for reaction detection..."
        sleep 3

        # Verify cancel marker exists
        echo -e "\nChecking for cancel marker..."
        cancel_marker="${state_dir}/.cancel-${event_id}"
        if [[ -f "$cancel_marker" ]]; then
            echo "✓ Cancel marker created: $cancel_marker"
        else
            echo "✗ Cancel marker NOT found: $cancel_marker"
        fi

        # Verify metadata has desktop_reacted flag
        echo -e "\nChecking metadata for desktop_reacted flag..."
        desktop_reacted=$(cat "$metadata_file" | jq -r '.flags.desktop_reacted // empty')
        if [[ "$desktop_reacted" == "true" ]]; then
            echo "✓ Metadata updated with desktop_reacted: true"
        else
            echo "✗ Metadata NOT updated (desktop_reacted: $desktop_reacted)"
        fi

        echo -e "\nFinal metadata:"
        cat "$metadata_file" | jq .

        echo -e "\nState directory contents:"
        ls -la "$state_dir"

        echo -e "\nTest complete. Check debug log:"
        tail -n 5 /tmp/claude-hook-debug.log
        ;;
    "test-mobile-scheduler")
        # Test mobile notification scheduler with cancel scenarios
        echo "Testing schedule_mobile_notification function..."

        # Override delay for faster testing (5 seconds instead of 30)
        export TEST_MOBILE_DELAY=5

        # Initialize state
        state_dir=$(initialize_state_dir)
        echo "State directory: $state_dir"
        timers_dir="${state_dir}/timers"

        # Test 1: Schedule and verify PID stored
        echo -e "\nTest 1: Schedule timer and verify PID file creation"
        event_id=$(generate_event_id)
        echo "Event ID: $event_id"

        metadata_file=$(record_event_metadata "$event_id" "test" "Test mobile notification")
        echo "Created metadata: $metadata_file"

        schedule_mobile_notification "$event_id" "Test mobile notification message"

        timer_file="${timers_dir}/${event_id}.timer"
        if [[ -f "$timer_file" ]]; then
            timer_pid=$(cat "$timer_file")
            echo "✓ Timer file created: $timer_file (PID: $timer_pid)"

            # Verify process is running
            if kill -0 "$timer_pid" 2>/dev/null; then
                echo "✓ Timer process is running (PID: $timer_pid)"
            else
                echo "✗ Timer process not found (PID: $timer_pid)"
            fi
        else
            echo "✗ Timer file NOT created: $timer_file"
        fi

        # Test 2: Cancel via cancel marker
        echo -e "\nTest 2: Test cancellation via cancel marker"
        event_id2=$(generate_event_id)
        echo "Event ID: $event_id2"

        metadata_file2=$(record_event_metadata "$event_id2" "test" "Test cancellation")
        schedule_mobile_notification "$event_id2" "This should be cancelled"

        timer_file2="${timers_dir}/${event_id2}.timer"
        echo "Timer scheduled: $timer_file2"

        # Create cancel marker immediately
        cancel_marker="${state_dir}/.cancel-${event_id2}"
        touch "$cancel_marker"
        echo "Created cancel marker: $cancel_marker"

        # Wait for timer to complete (should exit early due to cancel marker)
        echo "Waiting for timer to check cancel marker..."
        sleep 6

        # Verify timer cleaned up
        if [[ ! -f "$timer_file2" ]]; then
            echo "✓ Timer file cleaned up after cancellation"
        else
            echo "✗ Timer file still exists: $timer_file2"
        fi

        # Test 3: Cancel via superseded flag
        echo -e "\nTest 3: Test cancellation via superseded flag"
        event_id3=$(generate_event_id)
        echo "Event ID: $event_id3"

        metadata_file3=$(record_event_metadata "$event_id3" "test" "Test superseded")
        schedule_mobile_notification "$event_id3" "This should be superseded"

        timer_file3="${timers_dir}/${event_id3}.timer"
        echo "Timer scheduled: $timer_file3"

        # Mark event as superseded
        update_event_field "$event_id3" "flags.superseded" "true"
        echo "Marked event as superseded"
        echo "Metadata superseded flag: $(jq -r '.flags.superseded' "$metadata_file3")"

        # Wait for timer to complete (should exit early due to superseded flag)
        echo "Waiting for timer to check superseded flag..."
        sleep 6

        # Verify timer cleaned up
        if [[ ! -f "$timer_file3" ]]; then
            echo "✓ Timer file cleaned up after superseded"
        else
            echo "✗ Timer file still exists: $timer_file3"
        fi

        # Test 4: Successful notification (no cancel, no superseded)
        echo -e "\nTest 4: Test successful notification delivery"
        event_id4=$(generate_event_id)
        echo "Event ID: $event_id4"

        metadata_file4=$(record_event_metadata "$event_id4" "test" "Test successful delivery")
        schedule_mobile_notification "$event_id4" "This should be delivered"

        timer_file4="${timers_dir}/${event_id4}.timer"
        echo "Timer scheduled: $timer_file4"
        echo "Waiting ${TEST_MOBILE_DELAY}s for notification to send..."

        # Wait for timer to complete and send notification
        sleep 6

        # Verify timer cleaned up
        if [[ ! -f "$timer_file4" ]]; then
            echo "✓ Timer file cleaned up after delivery"
        else
            echo "✗ Timer file still exists: $timer_file4"
        fi

        echo -e "\nState directory contents:"
        ls -la "$state_dir"
        echo -e "\nTimers directory contents:"
        ls -la "$timers_dir" 2>/dev/null || echo "No timer files (expected)"

        echo -e "\nTest complete. Check debug log for details:"
        tail -n 20 /tmp/claude-hook-debug.log | grep -E "(Mobile notification|schedule_mobile_notification)"

        unset TEST_MOBILE_DELAY
        ;;
    "test-user-activity")
        # Test on_user_activity function with various scenarios
        echo "Testing on_user_activity function..."

        # Override delay for faster testing
        export TEST_MOBILE_DELAY=30

        # Initialize state
        state_dir=$(initialize_state_dir)
        echo "State directory: $state_dir"
        timers_dir="${state_dir}/timers"

        # Test 1: Kill pending timers
        echo -e "\nTest 1: Verify timer cleanup on user activity"

        # Create some test events with timers
        event_id1=$(generate_event_id)
        metadata_file1=$(record_event_metadata "$event_id1" "test" "Event 1")
        schedule_mobile_notification "$event_id1" "Event 1 notification"

        event_id2=$(generate_event_id)
        metadata_file2=$(record_event_metadata "$event_id2" "test" "Event 2")
        schedule_mobile_notification "$event_id2" "Event 2 notification"

        echo "Created 2 active timers"
        echo "Timers before on_user_activity:"
        ls -la "$timers_dir"/*.timer 2>/dev/null || echo "No timer files"

        # Trigger user activity
        echo -e "\nTriggering on_user_activity..."
        on_user_activity

        # Verify timers were killed
        echo -e "\nTimers after on_user_activity:"
        ls -la "$timers_dir"/*.timer 2>/dev/null || echo "No timer files (cleanup successful)"

        # Test 2: Create cancel markers for active events
        echo -e "\nTest 2: Verify cancel markers created for active events"

        # Create new events (some superseded, some active)
        event_id3=$(generate_event_id)
        metadata_file3=$(record_event_metadata "$event_id3" "test" "Active event 3")
        schedule_mobile_notification "$event_id3" "Event 3 notification"

        event_id4=$(generate_event_id)
        metadata_file4=$(record_event_metadata "$event_id4" "test" "Superseded event 4")
        schedule_mobile_notification "$event_id4" "Event 4 notification"
        update_event_field "$event_id4" "flags.superseded" "true"  # Mark as superseded

        event_id5=$(generate_event_id)
        metadata_file5=$(record_event_metadata "$event_id5" "test" "Active event 5")
        schedule_mobile_notification "$event_id5" "Event 5 notification"

        echo "Created 3 events: 2 active, 1 superseded"
        echo "Metadata files:"
        ls -la "$state_dir"/*.json

        # Trigger user activity
        echo -e "\nTriggering on_user_activity..."
        on_user_activity

        # Verify cancel markers created for active events only
        echo -e "\nCancel markers after on_user_activity:"
        ls -la "$state_dir"/.cancel-* 2>/dev/null || echo "No cancel markers"

        # Check individual markers
        if [[ -f "$state_dir/.cancel-${event_id3}" ]]; then
            echo "✓ Cancel marker created for active event 3"
        else
            echo "✗ Cancel marker NOT created for active event 3"
        fi

        if [[ -f "$state_dir/.cancel-${event_id4}" ]]; then
            echo "✗ Cancel marker incorrectly created for superseded event 4"
        else
            echo "✓ Cancel marker correctly NOT created for superseded event 4"
        fi

        if [[ -f "$state_dir/.cancel-${event_id5}" ]]; then
            echo "✓ Cancel marker created for active event 5"
        else
            echo "✗ Cancel marker NOT created for active event 5"
        fi

        # Test 3: Graceful handling of missing state directory
        echo -e "\nTest 3: Test graceful handling of missing state directory"

        # Remove state directory
        rm -rf "$state_dir"
        echo "Removed state directory"

        # Trigger user activity (should not error)
        echo "Triggering on_user_activity with missing state directory..."
        on_user_activity && {
            echo "✓ on_user_activity handled missing state directory gracefully"
        } || {
            echo "✗ on_user_activity failed with missing state directory"
        }

        # Test 4: Backward compatibility - legacy state file cleanup
        echo -e "\nTest 4: Test legacy state file cleanup"

        # Create legacy state files
        touch "$IDLE_STATE_FILE"
        echo "99999" > "$IDLE_DETECTOR_PID_FILE"
        echo "Created legacy state files"
        echo "  IDLE_STATE_FILE: $IDLE_STATE_FILE"
        echo "  IDLE_DETECTOR_PID_FILE: $IDLE_DETECTOR_PID_FILE"

        # Trigger user activity
        echo -e "\nTriggering on_user_activity..."
        on_user_activity

        # Verify legacy files cleaned up
        if [[ ! -f "$IDLE_STATE_FILE" ]]; then
            echo "✓ Legacy IDLE_STATE_FILE cleaned up"
        else
            echo "✗ Legacy IDLE_STATE_FILE still exists"
        fi

        if [[ ! -f "$IDLE_DETECTOR_PID_FILE" ]]; then
            echo "✓ Legacy IDLE_DETECTOR_PID_FILE cleaned up"
        else
            echo "✗ Legacy IDLE_DETECTOR_PID_FILE still exists"
        fi

        echo -e "\nTest complete. Check debug log for details:"
        tail -n 30 /tmp/claude-hook-debug.log | grep -E "(User activity|cancel marker|timer)"

        unset TEST_MOBILE_DELAY
        ;;
    "test-stop-handler")
        # Test mark_claude_finished function with full event lifecycle
        echo "Testing mark_claude_finished function..."

        # Override delay for faster testing
        export TEST_MOBILE_DELAY=5

        # Initialize state
        state_dir=$(initialize_state_dir)
        echo "State directory: $state_dir"
        timers_dir="${state_dir}/timers"

        # Test 1: Full event lifecycle with mock transcript
        echo -e "\nTest 1: Full stop handler event lifecycle"

        # Create a mock transcript file
        mock_transcript="/tmp/test-transcript-$$.jsonl"
        cat > "$mock_transcript" <<'EOF'
{"role":"assistant","message":{"content":[{"type":"text","text":"I've successfully implemented the new notification system with dual-channel support."}]}}
EOF
        echo "Created mock transcript: $mock_transcript"

        # Create mock hook input with transcript path
        mock_hook_input=$(jq -n --arg path "$mock_transcript" '{transcript_path: $path}')

        # Trigger stop handler with mock input
        echo -e "\nTriggering mark_claude_finished with mock transcript..."
        echo "$mock_hook_input" | "$0" claude-finished

        # Wait briefly for processing
        sleep 1

        # Verify state directory has event metadata
        echo -e "\nState directory contents:"
        ls -la "$state_dir"

        # Find the event ID (newest JSON file)
        event_id=$(ls -t "$state_dir"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json$//')
        if [[ -z "$event_id" ]]; then
            echo "✗ No event metadata created"
        else
            echo "✓ Event created: $event_id"

            # Verify metadata structure
            metadata_file="$state_dir/${event_id}.json"
            echo -e "\nEvent metadata:"
            cat "$metadata_file" | jq .

            # Check required fields
            event_type=$(jq -r '.event_type' "$metadata_file")
            summary=$(jq -r '.summary' "$metadata_file")
            session_id=$(jq -r '.session_id' "$metadata_file")

            if [[ "$event_type" == "stop" ]]; then
                echo "✓ Event type is 'stop'"
            else
                echo "✗ Event type is '$event_type' (expected 'stop')"
            fi

            if [[ -n "$summary" && "$summary" != "null" ]]; then
                echo "✓ Summary generated: $summary"
            else
                echo "✗ Summary missing or null"
            fi

            if [[ -n "$session_id" && "$session_id" != "null" ]]; then
                echo "✓ Session ID set: $session_id"
            else
                echo "✗ Session ID missing or null"
            fi

            # Verify timer scheduled
            timer_file="$timers_dir/${event_id}.timer"
            if [[ -f "$timer_file" ]]; then
                timer_pid=$(cat "$timer_file")
                echo "✓ Mobile notification timer scheduled (PID: $timer_pid)"

                # Verify timer process is running
                if kill -0 "$timer_pid" 2>/dev/null; then
                    echo "✓ Timer process is running"
                else
                    echo "✗ Timer process not found"
                fi
            else
                echo "✗ Timer file not created: $timer_file"
            fi

            # Test 2: Verify supersession on second event
            echo -e "\nTest 2: Verify supersession on second event"

            # Trigger another stop handler
            echo -e "\nTriggering second mark_claude_finished..."
            echo "$mock_hook_input" | "$0" claude-finished

            sleep 1

            # Find the new event ID
            event_id2=$(ls -t "$state_dir"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json$//')

            if [[ "$event_id2" != "$event_id" ]]; then
                echo "✓ New event created: $event_id2"

                # Verify first event was superseded
                superseded=$(jq -r '.flags.superseded' "$metadata_file")
                if [[ "$superseded" == "true" ]]; then
                    echo "✓ First event marked as superseded"
                else
                    echo "✗ First event NOT marked as superseded (superseded: $superseded)"
                fi

                # Verify first event's timer was killed
                if [[ ! -f "$timers_dir/${event_id}.timer" ]]; then
                    echo "✓ First event's timer was killed"
                else
                    echo "✗ First event's timer still exists"
                fi
            else
                echo "✗ Second event was not created (same event_id)"
            fi

            # Test 3: Verify desktop reaction detection
            echo -e "\nTest 3: Verify desktop reaction detection (wait 3s)..."
            sleep 3

            # Check for cancel marker
            cancel_marker="$state_dir/.cancel-${event_id2}"
            if [[ -f "$cancel_marker" ]]; then
                echo "✓ Cancel marker created after desktop notification: $cancel_marker"
            else
                echo "✗ Cancel marker NOT found: $cancel_marker"
            fi

            # Check for desktop_reacted flag
            metadata_file2="$state_dir/${event_id2}.json"
            desktop_reacted=$(jq -r '.flags.desktop_reacted // empty' "$metadata_file2")
            if [[ "$desktop_reacted" == "true" ]]; then
                echo "✓ Metadata updated with desktop_reacted: true"
            else
                echo "✗ Metadata NOT updated (desktop_reacted: $desktop_reacted)"
            fi
        fi

        # Cleanup
        rm -f "$mock_transcript"

        echo -e "\nFinal state directory contents:"
        ls -la "$state_dir"

        echo -e "\nTest complete. Check debug log for details:"
        tail -n 30 /tmp/claude-hook-debug.log | grep -E "(Stop hook|event|desktop|mobile|superseded)"

        unset TEST_MOBILE_DELAY
        ;;
    "test-permission-handler")
        # Test on_permission_request function with full event lifecycle
        echo "Testing on_permission_request function..."

        # Override delay for faster testing
        export TEST_MOBILE_DELAY=5

        # Initialize state
        state_dir=$(initialize_state_dir)
        echo "State directory: $state_dir"
        timers_dir="${state_dir}/timers"

        # Test 1: Full event lifecycle with AskUserQuestion
        echo -e "\nTest 1: Full permission handler event lifecycle (AskUserQuestion)"

        # Create mock hook input with tool_name
        mock_hook_input=$(jq -n --arg tool "AskUserQuestion" '{tool_name: $tool}')

        # Trigger permission handler with mock input
        echo -e "\nTriggering on_permission_request with AskUserQuestion..."
        echo "$mock_hook_input" | "$0" permission-request

        # Wait briefly for processing
        sleep 1

        # Verify state directory has event metadata
        echo -e "\nState directory contents:"
        ls -la "$state_dir"

        # Find the event ID (newest JSON file)
        event_id=$(ls -t "$state_dir"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json$//')
        if [[ -z "$event_id" ]]; then
            echo "✗ No event metadata created"
        else
            echo "✓ Event created: $event_id"

            # Verify metadata structure
            metadata_file="$state_dir/${event_id}.json"
            echo -e "\nEvent metadata:"
            cat "$metadata_file" | jq .

            # Check required fields
            event_type=$(jq -r '.event_type' "$metadata_file")
            summary=$(jq -r '.summary' "$metadata_file")
            session_id=$(jq -r '.session_id' "$metadata_file")

            if [[ "$event_type" == "permission_request" ]]; then
                echo "✓ Event type is 'permission_request'"
            else
                echo "✗ Event type is '$event_type' (expected 'permission_request')"
            fi

            if [[ "$summary" == "Waiting for your answer" ]]; then
                echo "✓ Summary is permission-aware: $summary"
            else
                echo "✗ Summary not as expected: $summary (expected 'Waiting for your answer')"
            fi

            if [[ -n "$session_id" && "$session_id" != "null" ]]; then
                echo "✓ Session ID set: $session_id"
            else
                echo "✗ Session ID missing or null"
            fi

            # Verify timer scheduled
            timer_file="$timers_dir/${event_id}.timer"
            if [[ -f "$timer_file" ]]; then
                timer_pid=$(cat "$timer_file")
                echo "✓ Mobile notification timer scheduled (PID: $timer_pid)"

                # Verify timer process is running
                if kill -0 "$timer_pid" 2>/dev/null; then
                    echo "✓ Timer process is running"
                else
                    echo "✗ Timer process not found"
                fi
            else
                echo "✗ Timer file not created: $timer_file"
            fi
        fi

        # Test 2: Different tool types
        echo -e "\nTest 2: Test different tool types"

        # Test Edit permission
        mock_hook_input=$(jq -n --arg tool "Edit" '{tool_name: $tool}')
        echo -e "\nTriggering on_permission_request with Edit..."
        echo "$mock_hook_input" | "$0" permission-request
        sleep 1

        event_id2=$(ls -t "$state_dir"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json$//')
        metadata_file2="$state_dir/${event_id2}.json"
        summary2=$(jq -r '.summary' "$metadata_file2")

        if [[ "$summary2" == "Waiting for permission: File edit" ]]; then
            echo "✓ Edit tool message correct: $summary2"
        else
            echo "✗ Edit tool message incorrect: $summary2"
        fi

        # Test Bash permission
        mock_hook_input=$(jq -n --arg tool "Bash" '{tool_name: $tool}')
        echo -e "\nTriggering on_permission_request with Bash..."
        echo "$mock_hook_input" | "$0" permission-request
        sleep 1

        event_id3=$(ls -t "$state_dir"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json$//')
        metadata_file3="$state_dir/${event_id3}.json"
        summary3=$(jq -r '.summary' "$metadata_file3")

        if [[ "$summary3" == "Waiting for permission: Run command" ]]; then
            echo "✓ Bash tool message correct: $summary3"
        else
            echo "✗ Bash tool message incorrect: $summary3"
        fi

        # Test 3: Verify supersession between permission events
        echo -e "\nTest 3: Verify supersession on second permission request"

        # Verify earlier events were superseded
        superseded1=$(jq -r '.flags.superseded' "$metadata_file")
        superseded2=$(jq -r '.flags.superseded' "$metadata_file2")

        if [[ "$superseded1" == "true" ]]; then
            echo "✓ First event marked as superseded"
        else
            echo "✗ First event NOT marked as superseded"
        fi

        if [[ "$superseded2" == "true" ]]; then
            echo "✓ Second event marked as superseded"
        else
            echo "✗ Second event NOT marked as superseded"
        fi

        # Verify earlier timers were killed
        if [[ ! -f "$timers_dir/${event_id}.timer" ]]; then
            echo "✓ First event's timer was killed"
        else
            echo "✗ First event's timer still exists"
        fi

        if [[ ! -f "$timers_dir/${event_id2}.timer" ]]; then
            echo "✓ Second event's timer was killed"
        else
            echo "✗ Second event's timer still exists"
        fi

        # Test 4: Verify desktop reaction detection
        echo -e "\nTest 4: Verify desktop reaction detection (wait 3s)..."
        sleep 3

        # Check for cancel marker on latest event
        cancel_marker="$state_dir/.cancel-${event_id3}"
        if [[ -f "$cancel_marker" ]]; then
            echo "✓ Cancel marker created after desktop notification: $cancel_marker"
        else
            echo "✗ Cancel marker NOT found: $cancel_marker"
        fi

        # Check for desktop_reacted flag
        desktop_reacted=$(jq -r '.flags.desktop_reacted // empty' "$metadata_file3")
        if [[ "$desktop_reacted" == "true" ]]; then
            echo "✓ Metadata updated with desktop_reacted: true"
        else
            echo "✗ Metadata NOT updated (desktop_reacted: $desktop_reacted)"
        fi

        echo -e "\nFinal state directory contents:"
        ls -la "$state_dir"

        echo -e "\nTest complete. Check debug log for details:"
        tail -n 40 /tmp/claude-hook-debug.log | grep -E "(PermissionRequest|event|desktop|mobile|superseded)"

        unset TEST_MOBILE_DELAY
        ;;
    *)
        echo "Usage: $0 {claude-finished|user-activity|stop|permission-request|test|notify-with-summary|test-detect|test-desktop|test-summary|test-permission|test-session-id|test-state-dir|test-event-id|test-metadata|test-permission-summary|test-timer-cleanup|test-desktop-reaction|test-mobile-scheduler|test-user-activity|test-stop-handler|test-permission-handler}"
        exit 1
        ;;
esac
