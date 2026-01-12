#!/usr/bin/env bash
#
# run-final-tests.sh - Hook to run final validation suite before completion
#
# This hook is triggered on_build_complete or on_task_complete to run a comprehensive
# validation suite (tests, linting, type-checking, build) before signaling completion.
# It auto-detects the project type and runs appropriate validation commands.
#
# Intended to be used with mode=block to prevent completion if validation fails.
#
# Environment Variables (provided by wiggum):
#   WIGGUM_EVENT        - Event type (on_task_complete or on_build_complete)
#   WIGGUM_PROJECT_ROOT - Project root directory path
#
# Exit Codes:
#   0 - All validations passed
#   1 - One or more validations failed
#

set -euo pipefail

# Change to project root
PROJECT_ROOT="${WIGGUM_PROJECT_ROOT:-.}"
cd "$PROJECT_ROOT"

echo "Running final validation suite in: $PROJECT_ROOT" >&2
echo "" >&2

# Track overall success
VALIDATION_FAILED=0

# Helper function to run a command and track failures
run_validation() {
  local name="$1"
  shift

  echo "Running: $name" >&2
  if "$@"; then
    echo "  ✓ $name passed" >&2
  else
    echo "  ✗ $name failed" >&2
    VALIDATION_FAILED=1
  fi
  echo "" >&2
}

# Helper function to check if a command exists in package.json scripts
has_npm_script() {
  local script_name="$1"
  if [[ -f package.json ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -e ".scripts.\"$script_name\"" package.json >/dev/null 2>&1
    else
      grep -q "\"$script_name\"" package.json 2>/dev/null
    fi
  else
    return 1
  fi
}

# Detect project type and run appropriate validations

# Node.js / TypeScript projects
if [[ -f package.json ]]; then
  echo "Detected Node.js project" >&2
  echo "" >&2

  # Run tests
  if has_npm_script "test"; then
    run_validation "npm test" npm test
  else
    echo "Skipping tests (no 'test' script in package.json)" >&2
    echo "" >&2
  fi

  # Run linting
  if has_npm_script "lint"; then
    run_validation "npm run lint" npm run lint
  else
    echo "Skipping linting (no 'lint' script in package.json)" >&2
    echo "" >&2
  fi

  # Run type-checking for TypeScript projects
  if [[ -f tsconfig.json ]]; then
    if has_npm_script "typecheck"; then
      run_validation "npm run typecheck" npm run typecheck
    elif command -v tsc >/dev/null 2>&1; then
      run_validation "tsc --noEmit" tsc --noEmit
    else
      echo "Skipping type-checking (no 'typecheck' script and tsc not found)" >&2
      echo "" >&2
    fi
  fi

  # Run build
  if has_npm_script "build"; then
    run_validation "npm run build" npm run build
  else
    echo "Skipping build (no 'build' script in package.json)" >&2
    echo "" >&2
  fi

# Rust projects
elif [[ -f Cargo.toml ]]; then
  echo "Detected Rust project" >&2
  echo "" >&2

  # Run tests
  if command -v cargo >/dev/null 2>&1; then
    run_validation "cargo test" cargo test

    # Run clippy for linting
    if cargo clippy --version >/dev/null 2>&1; then
      run_validation "cargo clippy" cargo clippy -- -D warnings
    else
      echo "Skipping clippy (not installed)" >&2
      echo "" >&2
    fi

    # Run build
    run_validation "cargo build" cargo build --release
  else
    echo "ERROR: Cargo not found in PATH" >&2
    VALIDATION_FAILED=1
  fi

# Go projects
elif [[ -f go.mod ]]; then
  echo "Detected Go project" >&2
  echo "" >&2

  if command -v go >/dev/null 2>&1; then
    # Run tests
    run_validation "go test" go test ./...

    # Run vet for linting
    run_validation "go vet" go vet ./...

    # Run build
    run_validation "go build" go build ./...
  else
    echo "ERROR: Go not found in PATH" >&2
    VALIDATION_FAILED=1
  fi

# Python projects
elif [[ -f pyproject.toml ]] || [[ -f setup.py ]]; then
  echo "Detected Python project" >&2
  echo "" >&2

  # Run tests with pytest
  if command -v pytest >/dev/null 2>&1; then
    run_validation "pytest" pytest
  else
    echo "Skipping tests (pytest not found)" >&2
    echo "" >&2
  fi

  # Run ruff for linting
  if command -v ruff >/dev/null 2>&1; then
    run_validation "ruff check" ruff check .
  else
    echo "Skipping linting (ruff not found)" >&2
    echo "" >&2
  fi

  # Run mypy for type-checking
  if command -v mypy >/dev/null 2>&1; then
    run_validation "mypy" mypy .
  else
    echo "Skipping type-checking (mypy not found)" >&2
    echo "" >&2
  fi

else
  echo "WARNING: Could not detect project type" >&2
  echo "Supported project types:" >&2
  echo "  - Node.js/TypeScript (package.json)" >&2
  echo "  - Rust (Cargo.toml)" >&2
  echo "  - Go (go.mod)" >&2
  echo "  - Python (pyproject.toml or setup.py)" >&2
  echo "" >&2
  exit 0
fi

# Report final status
if [[ $VALIDATION_FAILED -eq 0 ]]; then
  echo "All validations passed" >&2
  exit 0
else
  echo "One or more validations failed" >&2
  exit 1
fi
