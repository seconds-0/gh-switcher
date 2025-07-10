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

# Helper to measure command execution time in milliseconds
measure_time_ms() {
    local start_ns=$(date +%s%N 2>/dev/null || echo "0")
    if [[ "$start_ns" == "0" ]]; then
        # macOS doesn't support nanoseconds, use python
        local start_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
        "$@" >/dev/null 2>&1
        local end_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
        echo $((end_ms - start_ms))
    else
        # Linux supports nanoseconds
        "$@" >/dev/null 2>&1
        local end_ns=$(date +%s%N)
        echo $(( (end_ns - start_ns) / 1000000 ))
    fi
}

@test "ghs users completes within reasonable time" {
    local duration=$(measure_time_ms ghs users)
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 150ms for bash script startup overhead
    [[ "$duration" -lt 150 ]]
}

@test "ghs switch completes within 100ms" {
    # Need to be in a git repo for switch to work
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    local duration=$(measure_time_ms ghs switch 1)
    echo "# Duration: ${duration}ms" >&3
    [[ "$duration" -lt 100 ]]
}

@test "ghs add completes within 100ms" {
    local duration=$(measure_time_ms ghs add testperf)
    echo "# Duration: ${duration}ms" >&3
    [[ "$duration" -lt 100 ]]
}

@test "ghs status completes within 100ms" {
    local duration=$(measure_time_ms ghs status)
    echo "# Duration: ${duration}ms" >&3
    [[ "$duration" -lt 100 ]]
}

@test "ghs guard test completes within reasonable time" {
    # Guard operations make GitHub API calls which can be slow in CI
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    local duration=$(measure_time_ms ghs guard test)
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 3000ms for guard test which makes GitHub API calls
    [[ "$duration" -lt 3000 ]]
}