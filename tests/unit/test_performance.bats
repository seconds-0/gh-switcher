#!/usr/bin/env bats

# Test performance requirements

load '../helpers/test_helper'
load '../helpers/ssh_helper'

setup() {
    setup_test_environment || { echo "setup_test_environment failed" >&2; return 1; }
    
    # Add some test users for realistic testing
    for i in {1..5}; do
        cmd_add "user$i" >/dev/null 2>&1 || true
    done
}

teardown() {
    cleanup_test_environment
}

# Helper to measure command execution time in milliseconds
measure_time_ms() {
    local start_ns=$(date +%s%N 2>/dev/null || echo "0")
    if [[ "$start_ns" == "0" ]]; then
        # macOS/Windows don't support nanoseconds
        # Use perl if available, otherwise fall back to seconds
        if command -v perl >/dev/null 2>&1; then
            local start_ms=$(perl -MTime::HiRes=time -e 'print int(time * 1000)')
            "$@" >/dev/null 2>&1
            local end_ms=$(perl -MTime::HiRes=time -e 'print int(time * 1000)')
            echo $((end_ms - start_ms))
        else
            # Fallback: just use seconds precision
            local start_s=$(date +%s)
            "$@" >/dev/null 2>&1
            local end_s=$(date +%s)
            echo $(( (end_s - start_s) * 1000 ))
        fi
    else
        # Linux supports nanoseconds
        "$@" >/dev/null 2>&1
        local end_ns=$(date +%s%N)
        echo $(( (end_ns - start_ns) / 1000000 ))
    fi
}


@test "ghs users completes within reasonable time" {
    local duration=$(measure_time_ms cmd_users)
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 350ms for bash script startup overhead with profile lookups including host info
    # CI environments may be slower, allow extra time
    local threshold=350
    [[ -n "${CI:-}" ]] && threshold=500
    # Windows is even slower due to POSIX emulation
    [[ "$OSTYPE" == "msys" ]] && threshold=$((threshold * ${GHS_PERF_MULTIPLIER:-2}))
    [[ "$duration" -lt "$threshold" ]]
}

@test "ghs switch completes within 100ms" {
    # Need to be in a git repo for switch to work
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    local duration=$(measure_time_ms cmd_switch 1)
    echo "# Duration: ${duration}ms" >&3
    # CI environments may be slower
    local threshold=100
    [[ -n "${CI:-}" ]] && threshold=200
    # Windows is even slower due to POSIX emulation
    [[ "$OSTYPE" == "msys" ]] && threshold=$((threshold * ${GHS_PERF_MULTIPLIER:-2}))
    [[ "$duration" -lt "$threshold" ]]
}

@test "ghs add completes within 100ms" {
    local duration=$(measure_time_ms cmd_add testperf)
    echo "# Duration: ${duration}ms" >&3
    # CI environments may be slower
    local threshold=100
    [[ -n "${CI:-}" ]] && threshold=200
    # Windows is even slower due to POSIX emulation
    [[ "$OSTYPE" == "msys" ]] && threshold=$((threshold * ${GHS_PERF_MULTIPLIER:-2}))
    [[ "$duration" -lt "$threshold" ]]
}

@test "ghs status completes within 250ms" {
    local duration=$(measure_time_ms cmd_status)
    echo "# Duration: ${duration}ms" >&3
    # CI environments may be slower
    local threshold=250
    [[ -n "${CI:-}" ]] && threshold=400
    # Windows is even slower due to POSIX emulation
    [[ "$OSTYPE" == "msys" ]] && threshold=$((threshold * ${GHS_PERF_MULTIPLIER:-2}))
    [[ "$duration" -lt "$threshold" ]]
}

@test "ghs guard test completes within reasonable time" {
    # Guard operations make GitHub API calls which can be slow in CI
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    local duration=$(measure_time_ms cmd_guard test)
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 3000ms for guard test which makes GitHub API calls
    local threshold=3000
    # Windows is even slower due to POSIX emulation
    [[ "$OSTYPE" == "msys" ]] && threshold=$((threshold * ${GHS_PERF_MULTIPLIER:-2}))
    [[ "$duration" -lt "$threshold" ]]
}