#!/usr/bin/env zsh

# O3-Pro Debug Step 4: Analyze _smart_tab_handler implementation and fzf-tab interaction
# Test the complete chain: _smart_tab_handler → fzf-tab-complete → ghost text system

echo "=== O3-Pro Debug Step 4: Smart Tab Handler Analysis ==="
echo "Testing the complete chain: _smart_tab_handler → fzf-tab-complete → ghost text"
echo

# Test 1: Verify _smart_tab_handler function exists and is bound
echo "1. Testing _smart_tab_handler existence and binding:"
echo -n "  - Function exists: "
if [[ $(type -w _smart_tab_handler 2>/dev/null) == *"function"* ]]; then
    echo "✅ YES"
else
    echo "❌ NO"
fi

echo -n "  - Tab binding (^I): "
if [[ "$(bindkey '^I' 2>/dev/null)" == *"_smart_tab_handler"* ]]; then
    echo "✅ Bound to _smart_tab_handler"
else
    echo "❌ Not bound or different binding"
    echo "    Current binding: $(bindkey '^I')"
fi

echo -n "  - Vi insert binding: "
if [[ "$(bindkey -M viins '^I' 2>/dev/null)" == *"_smart_tab_handler"* ]]; then
    echo "✅ Bound in vi-mode"
else
    echo "❌ Not bound in vi-mode"
fi

# Test 2: Check widget registration
echo
echo "2. Testing widget registration:"
echo -n "  - _smart_tab_handler widget: "
if (( $+widgets[_smart_tab_handler] )); then
    echo "✅ Registered as widget"
else
    echo "❌ Not registered as widget"
fi

# Test 3: Verify fzf-tab-complete widget availability in the handler
echo
echo "3. Testing widget availability in _smart_tab_handler context:"
echo -n "  - fzf-tab-complete widget check: "
if (( $+widgets[fzf-tab-complete] )); then
    echo "✅ Available (\$+widgets[fzf-tab-complete] = ${+widgets[fzf-tab-complete]})"
else
    echo "❌ Not available"
fi

echo -n "  - .fzf-tab-orig-expand-or-complete fallback: "
if (( $+widgets[.fzf-tab-orig-expand-or-complete] )); then
    echo "✅ Available"
else
    echo "❌ Not available"
fi

# Test 4: Check ghost text system variables
echo
echo "4. Testing ghost text system state:"
echo "  - GHOST_SHELL_PID: ${GHOST_SHELL_PID:-"NOT SET"}"
echo "  - _ghost_completion_active: ${_ghost_completion_active:-"NOT SET"}"
echo "  - GHOST_SYNC_MODE: ${GHOST_SYNC_MODE:-"NOT SET"}"
echo "  - Current POSTDISPLAY: '${POSTDISPLAY}'"

# Test 5: Check signal handler registration
echo
echo "5. Testing signal handler system:"
echo -n "  - TRAPUSR1 function: "
if [[ $(type -w TRAPUSR1 2>/dev/null) == *"function"* ]]; then
    echo "✅ Registered"
else
    echo "❌ Not registered"
fi

echo -n "  - _update_ghost_from_fzf widget: "
if (( $+widgets[_update_ghost_from_fzf] )); then
    echo "✅ Registered as widget"
else
    echo "❌ Not registered as widget"
fi

# Test 6: Create a minimal test to simulate _smart_tab_handler behavior
echo
echo "6. Testing _smart_tab_handler execution simulation:"

# Create a test function that mimics what _smart_tab_handler does
function _test_smart_tab_execution {
    echo "  Testing _smart_tab_handler logic flow..."
    
    # Check if we're in ZLE context (we won't be in this script)
    if [[ -o zle ]]; then
        echo "    - ZLE context: ✅ Available"
    else
        echo "    - ZLE context: ❌ Not available (expected in script)"
    fi
    
    # Test the widget existence check that _smart_tab_handler uses
    if (( $+widgets[fzf-tab-complete] )); then
        echo "    - Would call: fzf-tab-complete ✅"
    else
        echo "    - Would call: .fzf-tab-orig-expand-or-complete ❌"
    fi
    
    # Test ghost text variables
    local saved_active=$_ghost_completion_active
    _ghost_completion_active=true
    echo "    - Set _ghost_completion_active to: $_ghost_completion_active"
    
    # Test POSTDISPLAY clearing
    local saved_postdisplay=$POSTDISPLAY
    POSTDISPLAY=""
    echo "    - Cleared POSTDISPLAY: '${POSTDISPLAY}'"
    
    # Restore variables
    _ghost_completion_active=$saved_active
    POSTDISPLAY=$saved_postdisplay
    
    echo "    - Restored variables ✅"
}

_test_smart_tab_execution

# Test 7: Check fzf-tab bindings and configuration
echo
echo "7. Testing fzf-tab configuration:"

echo "  - fzf-tab bindings style:"
zstyle -L ':fzf-tab:*' fzf-bindings | head -3

echo "  - fzf-tab switch-group:"
zstyle -L ':fzf-tab:*' switch-group

# Test 8: Check for potential conflicts
echo
echo "8. Testing for potential conflicts:"

echo -n "  - Multiple Tab handlers: "
local tab_bindings=($(bindkey | grep '\^I' | wc -l))
if [[ $tab_bindings -gt 1 ]]; then
    echo "⚠️  Multiple bindings found:"
    bindkey | grep '\^I'
else
    echo "✅ Single binding"
fi

echo -n "  - ZLE conflicts: "
if [[ -n "$ZLE_RPROMPT_INDENT" ]] || [[ -n "$ZLE_REMOVE_SUFFIX_CHARS" ]]; then
    echo "⚠️  ZLE variables set: ZLE_RPROMPT_INDENT=$ZLE_RPROMPT_INDENT ZLE_REMOVE_SUFFIX_CHARS=$ZLE_REMOVE_SUFFIX_CHARS"
else
    echo "✅ No obvious ZLE conflicts"
fi

# Test 9: Test file system for ghost text mechanism
echo
echo "9. Testing ghost text file mechanism:"

local ghost_file="/tmp/fzf-selection-$$"
echo "  - Ghost text file path: $ghost_file"

echo -n "  - Temp directory writable: "
if [[ -w "/tmp" ]]; then
    echo "✅ YES"
    
    # Test write/read capability
    echo "test" > "$ghost_file" 2>/dev/null
    if [[ -r "$ghost_file" ]]; then
        echo "  - File creation/read test: ✅ SUCCESS"
        rm -f "$ghost_file" 2>/dev/null
    else
        echo "  - File creation/read test: ❌ FAILED"
    fi
else
    echo "❌ NO - this will break ghost text system"
fi

# Test 10: Create a controlled test to isolate the issue
echo
echo "10. Creating isolated test case:"

cat << 'EOF' > /tmp/test_smart_tab_isolated.zsh
#!/usr/bin/env zsh

# Minimal reproduction of the _smart_tab_handler issue
# This simulates what happens when Tab is pressed

echo "=== Isolated _smart_tab_handler Test ==="

# Check if we can load the function
if [[ -f ~/.zshrc ]]; then
    # Source just the function definitions we need
    source <(grep -A 20 "function _smart_tab_handler" ~/.zshrc | head -20)
    source <(grep -A 15 "function _update_ghost_from_fzf" ~/.zshrc | head -15)
    source <(grep -A 5 "function TRAPUSR1" ~/.zshrc | head -5)
    
    echo "✅ Functions sourced"
    
    # Test the conditions that _smart_tab_handler checks
    echo "Testing widget availability:"
    echo "  - fzf-tab-complete: $+widgets[fzf-tab-complete]"
    echo "  - .fzf-tab-orig-expand-or-complete: $+widgets[.fzf-tab-orig-expand-or-complete]"
    
    # Test variable states
    echo "Testing ghost text variables:"
    echo "  - _ghost_completion_active: ${_ghost_completion_active:-UNSET}"
    echo "  - POSTDISPLAY: '${POSTDISPLAY}'"
    
else
    echo "❌ Cannot access ~/.zshrc"
fi
EOF

echo "  - Created isolated test script: /tmp/test_smart_tab_isolated.zsh"

# Test 11: Check for any errors in the function definition
echo
echo "11. Testing function syntax and errors:"

echo -n "  - _smart_tab_handler syntax: "
if zsh -n -c "$(type -f _smart_tab_handler 2>/dev/null)" 2>/dev/null; then
    echo "✅ Valid syntax"
else
    echo "❌ Syntax errors detected"
fi

echo -n "  - Function definition complete: "
if [[ "$(type -f _smart_tab_handler 2>/dev/null)" == *"return"* ]]; then
    echo "✅ Complete with return statement"
else
    echo "❌ Incomplete or missing return"
fi

# Summary and next steps
echo
echo "=== SUMMARY AND NEXT STEPS ==="
echo "This step analyzed the _smart_tab_handler implementation."
echo
echo "Key findings to investigate:"
echo "1. Does _smart_tab_handler actually call fzf-tab-complete when Tab is pressed?"
echo "2. Are there any silent errors when the widget chain executes?"
echo "3. Is the ghost text update mechanism working but not being triggered?"
echo "4. Are the fzf-tab bindings properly configured to send signals?"
echo
echo "To complete the diagnosis:"
echo "1. Run the isolated test: zsh /tmp/test_smart_tab_isolated.zsh"
echo "2. Test manual widget invocation in a ZLE context"
echo "3. Check if fzf-tab actually uses the configured bindings"
echo "4. Verify the signal mechanism works end-to-end"
echo
echo "Next: Test actual Tab key behavior and fzf-tab signal generation"