#!/bin/bash
# Pre-commit script to run tests and lint

set -e

echo "🔍 Running ShellCheck..."
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x -e SC1091,SC2155,SC2181 gh-switcher.sh
    echo "✅ ShellCheck passed"
else
    echo "⚠️  ShellCheck not available, skipping"
fi

echo "🧪 Running tests..."
if command -v bats >/dev/null 2>&1; then
    # Run tests and check for the exact expected count
    output=$(bats -r tests 2>&1)
    echo "$output"
    
    # Check if we got the expected number of tests
    if echo "$output" | grep -q "56 tests, 0 failures"; then
        echo "✅ All 56 tests passed"
    elif echo "$output" | grep -q "Executed .* instead of expected 56 tests"; then
        echo "❌ Test count mismatch detected"
        exit 1
    else
        echo "❌ Tests failed or unexpected output"
        exit 1
    fi
else
    echo "⚠️  BATS not available, skipping tests"
fi

echo "✅ Pre-commit checks passed"
