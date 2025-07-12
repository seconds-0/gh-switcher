#!/usr/bin/env bats

# Essential guard hook operations tests

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_guard_test_environment
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
}

teardown() {
    cleanup_guard_test_environment
}

# Core install/uninstall functionality

@test "ghs guard install creates working hook" {
    run_guard_command "install"
    assert_success
    assert_output_contains "Guard hooks installed for test-repo"
    
    # Verify hook is installed and executable
    [[ -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
    [[ -x "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
    grep -q "GHS_GUARD_HOOK" "$TEST_GIT_REPO/.git/hooks/pre-commit"
}

@test "ghs guard install handles already installed hooks" {
    run_guard_command "install"
    assert_success
    
    # Install again - should succeed without backup since it's the same hook
    run_guard_command "install"
    assert_success
    assert_output_contains "Guard hooks installed for test-repo"
}

@test "ghs guard install backs up existing hooks" {
    create_existing_precommit_hook "#!/bin/bash\necho \"Original hook\""
    
    run_guard_command "install"
    assert_success
    assert_output_contains "Backed up existing pre-commit hook"
    
    # Verify backup exists
    local backup_count=$(find "$TEST_GIT_REPO/.git/hooks/" -name "pre-commit.backup.*" -type f | wc -l)
    [[ "$backup_count" -gt 0 ]]
}

@test "ghs guard uninstall removes hooks" {
    run_guard_command "install"
    assert_success
    
    run_guard_command "uninstall"
    assert_success
    assert_output_contains "Guard hooks removed"
    
    [[ ! -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
}

@test "ghs guard uninstall handles no hooks to remove" {
    run_guard_command "uninstall"
    assert_success
    assert_output_contains "No pre-commit hook found"
}

# Hook execution validation

@test "guard hook validates successfully with correct setup" {
    run_guard_command "install"
    assert_success
    
    # Verify hook is installed correctly
    [[ -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
    [[ -x "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
    
    # Verify hook has correct content (self-contained v2)
    grep -q "GHS_GUARD_HOOK v2" "$TEST_GIT_REPO/.git/hooks/pre-commit"
    grep -q 'GH_PROJECT_CONFIG' "$TEST_GIT_REPO/.git/hooks/pre-commit"
    
    # Verify the underlying command works
    run_guard_command "test"
    assert_success
    assert_output_contains "Validation would pass"
}

@test "guard hook blocks commit with account mismatch" {
    setup_mock_gh_user "wronguser"
    run_guard_command "install"
    assert_success
    
    # Verify the underlying command fails with mismatch
    run_guard_command "test"
    assert_failure
    assert_output_contains "Account mismatch detected!"
}

@test "guard hook respects skip flag" {
    setup_mock_gh_user "wronguser"  # Would normally fail
    run_guard_command "install"
    assert_success
    
    cd "$TEST_GIT_REPO"
    GHS_SKIP_HOOK=1 run bash "$TEST_GUARD_SCRIPT"
    assert_success
}

@test "guard hook executes within performance requirements" {
    run_guard_command "install"
    assert_success
    
    # Time the hook execution using gdate if available, otherwise use seconds
    cd "$TEST_GIT_REPO"
    if command -v gdate >/dev/null 2>&1; then
        local start_ms=$(gdate +%s%3N 2>/dev/null || echo "0")
        run_guard_hook
        local end_ms=$(gdate +%s%3N 2>/dev/null || echo "1000")
        local execution_time=$((end_ms - start_ms))
        
        # Performance requirement: <300ms (reasonable for pre-commit validation)
        [[ $execution_time -lt 300 ]]
    else
        # Fallback to seconds-based timing
        local start_time=$(date +%s)
        run_guard_hook
        local end_time=$(date +%s)
        local execution_time=$((end_time - start_time))
        # Performance requirement: <1 second (generous fallback)
        [[ $execution_time -lt 1 ]]
    fi
}