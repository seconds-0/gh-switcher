#!/usr/bin/env bats

# Focused Windows integration tests for real risks

load '../helpers/test_helper'
load '../helpers/ssh_helper'
load '../helpers/git_helper'

setup() {
    # Debug output for CI
    echo "# DEBUG: OSTYPE=$OSTYPE, RUNNER_OS=$RUNNER_OS, /c/Windows exists: $([[ -d "/c/Windows" ]] && echo yes || echo no)" >&3
    
    # Only run on Windows - check multiple conditions
    if [[ "$OSTYPE" != "msys" ]] && [[ "$RUNNER_OS" != "Windows" ]] && [[ ! -d "/c/Windows" ]]; then
        skip "Windows-specific test"
    fi
    
    setup_test_environment
    setup_test_ssh_environment
    setup_git_test_environment
    
    # Add a test user
    cmd_add "testuser" >/dev/null 2>&1
}

teardown() {
    cleanup_git_test_environment
    cleanup_test_ssh_environment
    cleanup_test_environment
}

@test "Windows: project assignment survives path format changes" {
    # Create a test directory
    mkdir -p "$TEST_HOME/testproject"
    cd "$TEST_HOME/testproject"
    git init -q
    
    # Assign using current path (Git Bash normalized)
    run ghs assign testuser
    assert_success
    assert_output_contains "Assigned testuser to directory:"
    
    # Store the assigned path
    local assigned_path="$PWD"
    
    # Navigate away
    cd "$TEST_HOME"
    
    # Come back using potentially different format
    # (In real Windows, this might be C:\... but in tests it's the same)
    cd "$assigned_path"
    
    # Verify assignment still recognized
    run project_get_user_by_path "$PWD"
    assert_success
    assert_output "testuser"
    
    # Also test via the auto-switch test command
    run ghs auto-switch test
    assert_success
    assert_output_contains "testuser"
}

@test "Windows: git config handles domain-style usernames" {
    # Create profile with backslash in name
    run cmd_edit testuser --name "CORP\\alice.smith" --email "alice@corp.com"
    assert_success
    assert_output_contains "Profile updated"
    
    # Switch to user in a git repo
    mkdir -p "$TEST_HOME/gitrepo"
    cd "$TEST_HOME/gitrepo"
    git init -q
    
    run cmd_switch testuser
    assert_success
    
    # Verify git stored it correctly
    run git config user.name
    assert_success
    assert_output "CORP\\alice.smith"
    
    # Verify email too
    run git config user.email
    assert_success
    assert_output "alice@corp.com"
    
    # Verify it survives a round trip - check both values are set correctly
    local stored_name=$(git config user.name)
    local stored_email=$(git config user.email)
    [[ "$stored_name" == "CORP\\alice.smith" ]] || fail "Name not stored correctly: $stored_name"
    [[ "$stored_email" == "alice@corp.com" ]] || fail "Email not stored correctly: $stored_email"
}