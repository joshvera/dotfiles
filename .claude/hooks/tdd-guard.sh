#!/bin/bash

# TDD-Guard Hook for Claude Code
# Enforces Test-Driven Development by preventing production code changes without tests

# Get the project directory
PROJECT_DIR="$(pwd)"
TDD_GUARD_DIR="$PROJECT_DIR/.claude/tdd-guard"

# Check if this project has TDD-guard enabled
if [ ! -d "$TDD_GUARD_DIR" ]; then
    exit 0  # TDD-guard not enabled for this project
fi

# Get the tool name and file path from environment variables
TOOL_NAME="${CLAUDE_TOOL_NAME}"
FILE_PATH="${CLAUDE_FILE_PATH}"

# Only check for Write, Edit, and MultiEdit operations
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
    exit 0
fi

# Skip test files
if [[ "$FILE_PATH" == *"/test_"* ]] || [[ "$FILE_PATH" == *"/tests/"* ]] || [[ "$FILE_PATH" == *"Tests.swift" ]] || [[ "$FILE_PATH" == *"_test.rs" ]]; then
    exit 0
fi

# Only check implementation files for supported languages
if [[ "$FILE_PATH" != *".py" ]] && [[ "$FILE_PATH" != *".swift" ]] && [[ "$FILE_PATH" != *".rs" ]]; then
    exit 0
fi

# Determine which reporter to use based on file extension
if [[ "$FILE_PATH" == *".swift" ]]; then
    # Use our Swift marker-based reporter
    REPORTER="$HOME/github/tdd-guard/reporters/swift/.build/debug/tdd-guard-swift"
    if [ -x "$REPORTER" ]; then
        "$REPORTER" --project-dir "$PROJECT_DIR" >/dev/null 2>&1
        # Check if markers were found by examining the report
        if [ -f "$PROJECT_DIR/.claude/tdd-guard/data/swift-test.json" ]; then
            if grep -q '"state": "failed"' "$PROJECT_DIR/.claude/tdd-guard/data/swift-test.json" 2>/dev/null; then
                # TDD markers found - allow the change (this is good TDD practice)
                exit 0
            else
                echo "❌ TDD-GUARD BLOCKED: No failing tests found for Swift changes!"
                echo "📝 Write a test with XCTFail(\"TDD: implement ...\") first."
                exit 1
            fi
        else
            echo "❌ TDD-GUARD BLOCKED: No Swift test report generated!"
            exit 1
        fi
    else
        echo "❌ TDD-GUARD: Swift reporter not available at $REPORTER"
        exit 1
    fi
elif [[ "$FILE_PATH" == *".rs" ]]; then
    # Use our Rust marker-based reporter
    REPORTER="$HOME/github/tdd-guard/reporters/rust/target/debug/tdd-guard-rust"
    if [ -x "$REPORTER" ]; then
        "$REPORTER" --project-dir "$PROJECT_DIR" >/dev/null 2>&1
        # Check if markers were found by examining the report
        if [ -f "$PROJECT_DIR/.claude/tdd-guard/data/rust-test.json" ]; then
            if grep -q '"state": "failed"' "$PROJECT_DIR/.claude/tdd-guard/data/rust-test.json" 2>/dev/null; then
                # TDD markers found - allow the change (this is good TDD practice)
                exit 0
            else
                echo "❌ TDD-GUARD BLOCKED: No failing tests found for Rust changes!"
                echo "📝 Write a test with panic!(\"TDD: implement ...\") first."
                exit 1
            fi
        else
            echo "❌ TDD-GUARD BLOCKED: No Rust test report generated!"
            exit 1
        fi
    else
        echo "❌ TDD-GUARD: Rust reporter not available at $REPORTER"
        exit 1
    fi
else
    # Use original tdd-guard for Python/JS/PHP
    cd "$PROJECT_DIR"
    tdd-guard check --project-dir "$PROJECT_DIR" 2>&1
    
    # Check the exit code
    if [ $? -ne 0 ]; then
        echo "❌ TDD-GUARD BLOCKED: You must write a failing test before implementing production code!"
        echo "📝 Write a test in tests/ directory first, verify it fails, then implement the code."
        exit 1
    fi
fi

exit 0