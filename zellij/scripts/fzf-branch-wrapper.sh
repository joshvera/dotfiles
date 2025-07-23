#!/bin/bash
# Wrapper script to ensure proper interactive execution

# Ensure we're in a shell that can handle interactive input
exec < /dev/tty

echo "=== DEBUG: Starting fzf branch picker ==="
echo "Working directory: $(pwd)"

# Source the main script
source "$(dirname "$0")/gbranch-tab.sh"

echo "=== DEBUG: Running fzf-branch-picker ==="
# Run the function
fzf-branch-picker
exit_code=$?

echo "=== DEBUG: Function completed with exit code: $exit_code ==="

# Keep the shell open
echo "Press any key to continue..."
read -n 1