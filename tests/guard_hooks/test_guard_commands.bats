#!/usr/bin/env bats

# Unit tests for guard command logic and validation
# Focus on testing guard command parsing, validation logic, and error conditions

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

# Test guard command parsing and help

@test "ghs guard shows usage when no subcommand provided" {
    run_guard_command
    assert_failure
    assert_output_contains "Usage: ghs guard <subcommand>"
    assert_output_contains "Available subcommands:"
    assert_output_contains "install"
    assert_output_contains "uninstall"
    assert_output_contains "status"
    assert_output_contains "test"
}

@test "ghs guard shows usage for invalid subcommand" {
    run_guard_command "invalid"
    assert_failure
    assert_output_contains "Usage: ghs guard <subcommand>"
}

@test "ghs guard help includes examples" {
    run_guard_command
    assert_failure
    assert_output_contains "Examples:"
    assert_output_contains "ghs guard install"
    assert_output_contains "ghs guard status"
    assert_output_contains "ghs guard test"
}

# Test guard test command (validation logic)

@test "ghs guard test passes with matching account and complete git config" {
    setup_mock_git_config "Test User" "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Current GitHub user: testuser"
    assert_output_contains "Project assigned to: testuser"
    assert_output_contains "Account matches project assignment"
    assert_output_contains "Git config is complete"
    assert_output_contains "Overall status: Validation would pass"
}

@test "ghs guard test detects account mismatch" {
    setup_mock_gh_user "wronguser"
    setup_mock_git_config "Test User" "test@example.com"
    
    run_guard_command "test"
    assert_failure
    assert_output_contains "Current GitHub user: wronguser"
    assert_output_contains "Project assigned to: testuser"
    assert_output_contains "Account mismatch detected!"
    assert_output_contains "Commits would be blocked"
}

@test "ghs guard test handles missing project assignment" {
    # Clear project assignment
    echo "" > "$GH_PROJECT_CONFIG"
    setup_mock_git_config "Test User" "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "No project assignment found"
    assert_output_contains "Validation would show warning but allow commit"
}

@test "ghs guard test detects incomplete git config - missing name" {
    setup_mock_git_config "" "test@example.com"
    
    run_guard_command "test"
    assert_failure
    assert_output_contains "Git config incomplete!"
    assert_output_contains "Commits would be blocked"
}

@test "ghs guard test detects incomplete git config - missing email" {
    setup_mock_git_config "Test User" ""
    
    run_guard_command "test"
    assert_failure
    assert_output_contains "Git config incomplete!"
    assert_output_contains "Commits would be blocked"
}

@test "ghs guard test handles unauthenticated GitHub CLI" {
    setup_mock_gh_user  # No username = unauthenticated
    
    run_guard_command "test"
    assert_success
    assert_output_contains "GitHub CLI not authenticated"
    assert_output_contains "Validation would be skipped"
}

@test "ghs guard test falls back to global git config" {
    # Clear local git config
    clear_git_config "local"
    
    # Set global git config
    setup_mock_git_config "Global User" "global@example.com" "global"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Git config: Global User <global@example.com>"
    assert_output_contains "Git config is complete"
}

# Test guard status command

@test "ghs guard status shows not installed when no hooks present" {
    run_guard_command "status"
    assert_success
    assert_output_contains "Guard Status for test-repo"
    assert_output_contains "No guard hooks installed"
    assert_output_contains "Run 'ghs guard install' to enable protection"
}

@test "ghs guard status detects non-guard pre-commit hook" {
    create_existing_precommit_hook "#!/bin/bash\necho \"Different hook\""
    
    run_guard_command "status"
    assert_success
    assert_output_contains "Different pre-commit hook installed"
    assert_output_contains "Run 'ghs guard install' to enable gh-switcher protection"
}

@test "ghs guard status shows installed when guard hook active" {
    # Install guard hook first
    run_guard_command "install"
    assert_success
    
    # Then check status
    run_guard_command "status"
    assert_success
    assert_output_contains "Guard hooks installed and active"
    assert_output_contains "Current validation state:"
}

@test "ghs guard status fails outside git repository" {
    cd "$TEST_HOME"  # Outside git repo
    
    run_guard_command "status"
    assert_failure
    assert_output_contains "Not in a git repository"
}

# Test error conditions

@test "guard commands fail outside git repository" {
    cd "$TEST_HOME"  # Outside git repo
    
    run_guard_command "install"
    assert_failure
    assert_output_contains "Not in a git repository"
    
    run_guard_command "uninstall"
    assert_failure
    assert_output_contains "Not in a git repository"
}

@test "ghs guard handles missing guard-hook.sh script" {
    # Remove the guard script to simulate missing installation
    rm -f "$TEST_GUARD_SCRIPT"
    rm -f "$BATS_TEST_DIRNAME/../../scripts/guard-hook.sh"
    
    run_guard_command "install"
    assert_failure
    assert_output_contains "Guard hook script not found"
    assert_output_contains "Make sure gh-switcher is properly installed"
}