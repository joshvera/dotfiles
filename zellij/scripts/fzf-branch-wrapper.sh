#!/bin/bash
# Wrapper script to ensure proper interactive execution

# Ensure we're in a shell that can handle interactive input
exec < /dev/tty

# Source the main script
source "$(dirname "$0")/gbranch-tab.sh"

# Run the function
fzf-branch-picker

# Keep the shell open if successful
if [ $? -eq 0 ]; then
    echo "Press any key to continue..."
    read -n 1
fi