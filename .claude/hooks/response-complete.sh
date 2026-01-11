#!/usr/bin/env bash

# Trigger idle detection when Claude finishes responding
set -euo pipefail

# Start idle monitoring
~/.claude/hooks/idle-detector.sh claude-finished

exit 0