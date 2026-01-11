#!/usr/bin/env bash

# Custom idle detection for Claude Code in SSH/Zellij environments
# This creates a background process that monitors for idle state and sends notifications

set -euo pipefail

IDLE_TIMEOUT=${CLAUDE_IDLE_TIMEOUT:-30} # Default 30 seconds (configurable)
IDLE_STATE_FILE="/tmp/claude-idle-state-$(basename "$(pwd)")"
IDLE_DETECTOR_PID_FILE="/tmp/claude-idle-detector-$(basename "$(pwd)").pid"

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

# Function to send idle notification (mobile - ntfy)
send_idle_notification() {
    local config_file=""
    if [[ -f "$HOME/.claude/.config/claudetainer/ntfy.json" ]]; then
        config_file="$HOME/.claude/.config/claudetainer/ntfy.json"
    elif [[ -f "$HOME/.config/claude-native/ntfy.json" ]]; then
        config_file="$HOME/.config/claude-native/ntfy.json"
    else
        return 0
    fi

    if ! command -v jq > /dev/null 2>&1; then
        return 0
    fi

    local ntfy_topic
    ntfy_topic=$(jq -r '.ntfy_topic // ""' "$config_file" 2> /dev/null || echo "")
    local ntfy_server
    ntfy_server=$(jq -r '.ntfy_server // "https://ntfy.sh"' "$config_file" 2> /dev/null || echo "https://ntfy.sh")

    if [[ -z "$ntfy_topic" ]]; then
        return 0
    fi

    local cwd_basename
    cwd_basename=$(basename "$(pwd)")
    local title="Claude Code: $cwd_basename"
    local session_info=""
    if [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
        local hostname
        hostname=$(hostname)
        session_info=" → ${hostname}:${ZELLIJ_SESSION_NAME}"
    fi
    local message="Claude waiting for input (idle >${IDLE_TIMEOUT}s)${session_info}"
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
            "$ntfy_server/$ntfy_topic" > /dev/null 2>&1 || true
    else
        curl -s --max-time 5 \
            -H "Title: $title" \
            -H "Tags: $tags" \
            -d "$message" \
            "$ntfy_server/$ntfy_topic" > /dev/null 2>&1 || true
    fi
}

# Function to send desktop notification (macOS - immediate)
send_desktop_notification() {
    local title="Claude Code: $(basename "$(pwd)")"
    local message="Response ready"

    # No sound per user preference
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
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
                    
                    # Call the original script's test function
                    \"$0\" test
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
                    
                    # Call the original script's test function
                    \"$0\" test
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
mark_claude_finished() {
    local device_type
    device_type=$(detect_device_type)
    echo "$(date): Stop hook triggered - Claude finished (device: $device_type)" >> /tmp/claude-hook-debug.log

    # Kill any existing monitor first (prevents multiple timers)
    if [[ -f "$IDLE_DETECTOR_PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$IDLE_DETECTOR_PID_FILE" 2> /dev/null || echo "")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2> /dev/null; then
            kill "$old_pid" 2> /dev/null || true
        fi
        rm -f "$IDLE_DETECTOR_PID_FILE"
    fi

    if [[ "$device_type" == "desktop" ]]; then
        # Desktop: immediate notification, no idle timer
        send_desktop_notification
    else
        # Mobile: start idle monitor for 30s delayed ntfy notification
        touch "$IDLE_STATE_FILE"
        start_idle_monitor
    fi
}

# Function to stop idle monitoring (user provided input)
stop_idle_monitor() {
    rm -f "$IDLE_STATE_FILE"
    if [[ -f "$IDLE_DETECTOR_PID_FILE" ]]; then
        local pid
        pid=$(cat "$IDLE_DETECTOR_PID_FILE" 2> /dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2> /dev/null; then
            kill "$pid" 2> /dev/null || true
        fi
        rm -f "$IDLE_DETECTOR_PID_FILE"
    fi
}

# Main logic based on arguments
case "${1:-start}" in
    "claude-finished")
        mark_claude_finished
        ;;
    "user-activity")
        stop_idle_monitor
        ;;
    "stop")
        stop_idle_monitor
        ;;
    "test")
        send_idle_notification
        ;;
    "test-detect")
        echo "Device type: $(detect_device_type)"
        ;;
    "test-desktop")
        send_desktop_notification
        ;;
    *)
        echo "Usage: $0 {claude-finished|user-activity|stop|test|test-detect|test-desktop}"
        exit 1
        ;;
esac
