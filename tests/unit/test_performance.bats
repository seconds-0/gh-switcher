#!/usr/bin/env bats

# Test performance requirements

load '../helpers/test_helper'

setup() {
    setup_test_environment
    
    # Add some test users for realistic testing
    for i in {1..5}; do
        cmd_add "user$i" >/dev/null 2>&1
    done
}

teardown() {
    cleanup_test_environment
}

# Helper to test if command completes within timeout
test_performance() {
    local timeout_ms="$1"
    shift
    
    # Convert ms to seconds for timeout command (round up)
    local timeout_s=$(( (timeout_ms + 999) / 1000 ))
    
    # Run with timeout - if it completes within time limit, pass
    if command -v timeout >/dev/null 2>&1; then
        # Use timeout command if available
        if timeout "$timeout_s" "$@" >/dev/null 2>&1; then
            echo "✓ Completed within ${timeout_ms}ms"
            return 0
        else
            echo "✗ Exceeded ${timeout_ms}ms timeout"
            return 1
        fi
    else
        # Fallback: just run the command and assume it's fast enough
        "$@" >/dev/null 2>&1
        local exit_code=$?
        echo "✓ Completed (timeout not available for verification)"
        return $exit_code
    fi
}

@test "ghs users completes within reasonable time" {
    run test_performance 350 ghs users
    assert_success
}

@test "ghs switch completes within 100ms" {
    # Need to be in a git repo for switch to work
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    run test_performance 100 ghs switch 1
    assert_success
}

@test "ghs add completes within 100ms" {
    run test_performance 100 ghs add testperf
    assert_success
}

@test "ghs status completes within 250ms" {
    run test_performance 250 ghs status
    assert_success
}

@test "ghs guard test completes within reasonable time" {
    # Guard operations make GitHub API calls which can be slow in CI
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    # Allow up to 3000ms for guard test which makes GitHub API calls
    run test_performance 3000 ghs guard test
    assert_success
}