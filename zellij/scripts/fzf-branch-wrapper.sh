#!/bin/bash
# Wrapper script to ensure proper interactive execution

# Ensure we're in a shell that can handle interactive input
exec < /dev/tty

# Source the main script
source "$(dirname "$0")/gbranch-tab.sh"

# Run the function
fzf-branch-picker

# Exit immediately after successful operation to close the pane
exit 0