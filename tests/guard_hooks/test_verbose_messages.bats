#!/usr/bin/env bats

load ../helpers/test_helper
load ../helpers/guard_helper

setup() {
    setup_test_environment
    setup_guard_test_environment
}

teardown() {
    cleanup_guard_test_environment
    cleanup_test_environment
}

@test "guard hook shows verbose account mismatch message by default" {
    setup_mock_gh_user "testuser"
    run_guard_command "install"
    assert_success
    
    # Assign a different user to trigger mismatch
    echo "test-repo=different-user" > "$GH_PROJECT_CONFIG"
    
    cd "$TEST_GIT_REPO"
    run bash .git/hooks/pre-commit
    assert_failure
    
    # Check for verbose message components
    assert_output_contains "GH-SWITCHER GUARD HOOK - COMMIT PROTECTION ACTIVE"
    assert_output_contains "COMMIT BLOCKED: GitHub Account Mismatch"
    assert_output_contains "WHAT'S HAPPENING:"
    assert_output_contains "HOW TO FIX:"
    assert_output_contains "Switch to the correct account (RECOMMENDED)"
    assert_output_contains "For AI agents: Execute"
}

@test "guard hook shows terse message when verbose mode disabled" {
    setup_mock_gh_user "testuser"
    run_guard_command "install"
    assert_success
    
    # Assign a different user to trigger mismatch
    echo "test-repo=different-user" > "$GH_PROJECT_CONFIG"
    
    cd "$TEST_GIT_REPO"
    GHS_GUARD_VERBOSE=false run bash .git/hooks/pre-commit
    assert_failure
    
    # Check for terse message
    assert_output_contains "Account mismatch detected!"
    assert_output_not_contains "GH-SWITCHER GUARD HOOK"
    assert_output_not_contains "WHAT'S HAPPENING:"
}

@test "guard hook shows verbose no auth message" {
    run_guard_command "install"
    assert_success
    
    # Remove gh from PATH to simulate no auth
    cd "$TEST_GIT_REPO"
    PATH="/usr/bin:/bin" run bash .git/hooks/pre-commit
    assert_success  # Should succeed with warning
    
    assert_output_contains "GITHUB CLI NOT AUTHENTICATED"
    assert_output_contains "WHAT THIS MEANS:"
    assert_output_contains "TO ENABLE PROTECTION:"
    assert_output_contains "For AI agents: This is a warning only"
}

@test "guard hook shows verbose git email mismatch" {
    setup_mock_gh_user "testuser"
    run_guard_command "install"
    assert_success
    
    # Create a profile with specific email
    profile_create "testuser" "Test User" "test@example.com" "" ""
    echo "test-repo=testuser" > "$GH_PROJECT_CONFIG"
    
    # Set different git email
    cd "$TEST_GIT_REPO"
    git config user.email "wrong@example.com"
    
    run bash .git/hooks/pre-commit
    assert_success  # Should succeed with warning
    
    assert_output_contains "GIT CONFIGURATION MISMATCH"
    assert_output_contains "DETECTED MISMATCH:"
    assert_output_contains "GitHub profile email: test@example.com"
    assert_output_contains "Current git email:    wrong@example.com"
    assert_output_contains "For AI agents: Run"
}

@test "guard hook respects GHS_GUARD_VERBOSE environment variable" {
    setup_mock_gh_user "testuser"
    run_guard_command "install"
    assert_success
    
    # Test that verbose is true by default
    cd "$TEST_GIT_REPO"
    run grep "GHS_GUARD_VERBOSE.*true" .git/hooks/pre-commit
    assert_success
    
    # Test verbose can be disabled
    echo "test-repo=different-user" > "$GH_PROJECT_CONFIG"
    GHS_GUARD_VERBOSE=false run bash .git/hooks/pre-commit
    assert_failure
    assert_output_not_contains "HOW TO FIX:"
}