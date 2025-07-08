#!/usr/bin/env bats

# Essential guard command tests - focus on core user workflows

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_guard_test_environment
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
}

teardown() {
    cleanup_guard_test_environment
}

# Core guard command functionality

@test "ghs guard shows usage and help" {
    run_guard_command
    assert_output_contains "Usage: ghs guard <subcommand>"
    assert_output_contains "install"
    assert_output_contains "test"
    assert_output_contains "Examples:"
}

@test "ghs guard test validates successfully with correct setup" {
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Current GitHub user: testuser"
    assert_output_contains "Account matches project assignment"
    assert_output_contains "Validation would pass"
}

@test "ghs guard test detects account mismatch" {
    setup_mock_gh_user "wronguser"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_output_contains "Account mismatch detected!"
    assert_output_contains "wronguser"
    assert_output_contains "testuser"
}

@test "ghs guard test handles missing project assignment" {
    echo "" > "$GH_PROJECT_CONFIG"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "No project assignment found"
}

@test "ghs guard test detects incomplete git config" {
    cd "$TEST_GIT_REPO"
    git config --unset user.name || true
    git config --unset user.email || true
    
    run_guard_command "test"
    assert_output_contains "Git config incomplete!"
}

@test "ghs guard test handles unauthenticated GitHub CLI" {
    setup_mock_gh_user  # No username = unauthenticated
    
    run_guard_command "test"
    assert_success
    assert_output_contains "GitHub CLI not authenticated"
}

@test "ghs guard status shows installation state" {
    run_guard_command "status"
    assert_success
    assert_output_contains "Guard Status"
    assert_output_contains "No guard hooks installed"
}

@test "guard commands require git repository" {
    cd "$TEST_HOME"  # Outside git repo
    
    run_guard_command_here "install"
    assert_output_contains "Not in a git repository"
    
    run_guard_command_here "status"
    assert_output_contains "Not in a git repository"
}