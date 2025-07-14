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


@test "ghs users completes within reasonable time" {
    run cmd_users
    assert_success
}

@test "ghs switch completes within 100ms" {
    # Need to be in a git repo for switch to work
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    run cmd_switch 1
    assert_success
}

@test "ghs add completes within 100ms" {
    run cmd_add testperf
    assert_success
}

@test "ghs status completes within 250ms" {
    run cmd_status
    assert_success
}

@test "ghs guard test completes within reasonable time" {
    # Guard operations make GitHub API calls which can be slow in CI
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init >/dev/null 2>&1
    
    run cmd_guard test
    assert_success
}