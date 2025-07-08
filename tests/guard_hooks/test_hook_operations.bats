#!/usr/bin/env bats

# Integration tests for guard hook operations
# Focus on install/uninstall operations, backup functionality, and hook execution

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_guard_test_environment
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
}

teardown() {
    cleanup_guard_test_environment
}

# Test guard install operations

@test "ghs guard install creates symlink to guard-hook.sh" {
    run_guard_command "install"
    assert_success
    assert_output_contains "Guard hooks installed successfully"
    assert_output_contains "Commits will now be validated for account mismatches"
    assert_output_contains "GHS_SKIP_HOOK=1 git commit"
    
    assert_guard_hook_installed
}

@test "ghs guard install handles already installed hooks" {
    # Install once
    run_guard_command "install"
    assert_success
    
    # Install again
    run_guard_command "install"
    assert_success
    assert_output_contains "Guard hooks already installed"
    
    assert_guard_hook_installed
}

@test "ghs guard install backs up existing pre-commit hook" {
    create_existing_precommit_hook "#!/bin/bash\necho \"Original hook\""
    
    # Mock user input for backup confirmation
    echo "y" | run_guard_command "install"
    assert_success
    assert_output_contains "Existing pre-commit hook found"
    assert_output_contains "Backed up existing hook"
    assert_output_contains "Guard hooks installed successfully"
    
    assert_guard_hook_installed
    assert_backup_hook_exists
}

@test "ghs guard install cancels when user declines backup" {
    create_existing_precommit_hook "#!/bin/bash\necho \"Original hook\""
    
    # Mock user input declining backup
    echo "n" | run_guard_command "install"
    assert_failure
    assert_output_contains "Installation cancelled"
    
    assert_guard_hook_not_installed
}

# Test guard uninstall operations

@test "ghs guard uninstall removes guard hooks" {
    # Install first
    run_guard_command "install"
    assert_success
    assert_guard_hook_installed
    
    # Then uninstall
    run_guard_command "uninstall"
    assert_success
    assert_output_contains "Guard hooks removed"
    
    assert_guard_hook_not_installed
}

@test "ghs guard uninstall handles no hooks to remove" {
    run_guard_command "uninstall"
    assert_success
    assert_output_contains "No guard hooks to remove"
}

@test "ghs guard uninstall offers to restore backup hook" {
    # Create existing hook and install guard (creating backup)
    create_existing_precommit_hook "#!/bin/bash\necho \"Original hook\""
    echo "y" | run_guard_command "install"
    assert_success
    
    # Uninstall and restore backup
    echo "y" | run_guard_command "uninstall"
    assert_success
    assert_output_contains "Guard hooks removed"
    assert_output_contains "Previous hook backup found"
    assert_output_contains "Previous hook restored"
    
    # Verify original hook is restored
    [[ -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
    [[ ! -L "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]  # Not a symlink
    grep -q "Original hook" "$TEST_GIT_REPO/.git/hooks/pre-commit"
}

@test "ghs guard uninstall declines to restore backup when user says no" {
    # Create existing hook and install guard (creating backup)
    create_existing_precommit_hook "#!/bin/bash\necho \"Original hook\""
    echo "y" | run_guard_command "install"
    assert_success
    
    # Uninstall but decline restore
    echo "n" | run_guard_command "uninstall"
    assert_success
    assert_output_contains "Guard hooks removed"
    assert_output_contains "Previous hook backup found"
    
    # Verify no hook is present
    [[ ! -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
}

@test "ghs guard uninstall refuses to remove non-guard hooks" {
    create_existing_precommit_hook "#!/bin/bash\necho \"Different hook\""
    
    run_guard_command "uninstall"
    assert_failure
    assert_output_contains "Pre-commit hook exists but is not a guard hook"
    assert_output_contains "Not removing unknown hook"
    
    # Verify hook is still present
    [[ -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]
}

# Test guard hook execution

@test "guard hook validates successfully with correct setup" {
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test hook execution directly
    run_guard_hook
    assert_success
    assert_output_contains "gh-switcher pre-commit validation"
    assert_output_contains "Current GitHub user: testuser"
    assert_output_contains "Account matches project assignment"
    assert_output_contains "Pre-commit validation passed"
}

@test "guard hook blocks commit with account mismatch" {
    setup_mock_gh_user "wronguser"
    
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test hook execution - should fail
    run_guard_hook
    assert_failure
    assert_output_contains "Account mismatch detected!"
    assert_output_contains "Current user: wronguser"
    assert_output_contains "Project assigned to: testuser"
    assert_output_contains "Pre-commit validation failed"
}

@test "guard hook blocks commit with incomplete git config" {
    clear_git_config "local"
    clear_git_config "global"
    
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test hook execution - should fail
    run_guard_hook
    assert_failure
    assert_output_contains "Git config incomplete!"
    assert_output_contains "Pre-commit validation failed"
}

@test "guard hook skips validation when GitHub CLI unauthenticated" {
    setup_mock_gh_user  # Unauthenticated
    
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test hook execution - should pass with warning
    run_guard_hook
    assert_success
    assert_output_contains "GitHub CLI not authenticated"
    assert_output_contains "validation skipped"
}

@test "guard hook respects GHS_SKIP_HOOK environment variable" {
    setup_mock_gh_user "wronguser"  # This would normally fail
    
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test hook execution with skip flag
    cd "$TEST_GIT_REPO"
    GHS_SKIP_HOOK=1 run bash "$TEST_GUARD_SCRIPT"
    assert_success
    # Should exit early without any validation output
    [[ -z "$output" ]] || [[ "$output" =~ ^[[:space:]]*$ ]]
}

# Test hook path detection

@test "guard hook finds gh-switcher.sh via multiple path strategies" {
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Test with different path scenarios
    cd "$TEST_GIT_REPO"
    
    # Test 1: Explicit GH_SWITCHER_PATH
    GH_SWITCHER_PATH="$BATS_TEST_DIRNAME/../../gh-switcher.sh" run_guard_hook
    assert_success
    
    # Test 2: Git repository root detection
    unset GH_SWITCHER_PATH
    cp "$BATS_TEST_DIRNAME/../../gh-switcher.sh" "$TEST_GIT_REPO/gh-switcher.sh"
    run_guard_hook
    assert_success
}

# Test performance requirements

@test "guard hook execution completes quickly" {
    # Install guard hook
    run_guard_command "install"
    assert_success
    
    # Time the hook execution
    cd "$TEST_GIT_REPO"
    time_command bash "$TEST_GUARD_SCRIPT"
    assert_success
    
    # Assert it completes within 100ms (performance requirement)
    assert_command_fast 100
}

@test "guard test command completes quickly" {
    time_command run_guard_command "test"
    assert_success
    
    # Assert guard test completes within 100ms
    assert_command_fast 100
}