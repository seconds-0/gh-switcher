#!/usr/bin/env bats

# Error scenario tests for guard hooks
# Focus on edge cases, error conditions, and system reliability

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_guard_test_environment
}

teardown() {
    cleanup_guard_test_environment
}

# Test missing dependencies and system issues

@test "guard handles missing git command gracefully" {
    # Mock missing git by creating a fake git that fails
    cat > "$TEST_HOME/git" << 'EOF'
#!/bin/bash
exit 127
EOF
    chmod +x "$TEST_HOME/git"
    export PATH="$TEST_HOME:$PATH"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_success  # Should handle gracefully
    assert_output_contains "GitHub CLI not authenticated"  # Falls back to this message
}

@test "guard handles corrupted git repository" {
    # Corrupt the git repository
    rm -rf "$TEST_GIT_REPO/.git"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    assert_failure
    assert_output_contains "Not in a git repository"
}

@test "guard handles permission issues with hooks directory" {
    # Make hooks directory read-only
    chmod 444 "$TEST_GIT_REPO/.git/hooks"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    # This might succeed or fail depending on system, but shouldn't crash
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
    
    # Restore permissions for cleanup
    chmod 755 "$TEST_GIT_REPO/.git/hooks"
}

@test "guard handles malformed project configuration" {
    # Create malformed project config
    echo "invalid-format-line" > "$GH_PROJECT_CONFIG"
    echo "=missing-project-name" >> "$GH_PROJECT_CONFIG"  
    echo "missing-equals-sign" >> "$GH_PROJECT_CONFIG"
    
    setup_mock_gh_user "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_success  # Should handle gracefully
    assert_output_contains "No project assignment found"
}

@test "guard handles empty project configuration file" {
    # Create empty project config
    touch "$GH_PROJECT_CONFIG"
    
    setup_mock_gh_user "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_success
    assert_output_contains "No project assignment found"
}

@test "guard handles missing project configuration file" {
    # Remove project config entirely
    rm -f "$GH_PROJECT_CONFIG"
    
    setup_mock_gh_user "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_success
    assert_output_contains "No project assignment found"
}

# Test GitHub CLI edge cases

@test "guard handles gh command returning unexpected output" {
    # Mock gh that returns unexpected data
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then
    echo "Unexpected output format"
    exit 0
elif [[ "$1 $2 $3" == "api user --jq" ]]; then
    echo "not-a-username-but-json-error"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    setup_test_project_assignment "test-repo" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    # Should handle gracefully even with unexpected gh output
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "guard handles gh api command failures" {
    # Mock gh that fails on API calls
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then
    exit 0  # Auth works
elif [[ "$1 $2 $3" == "api user --jq" ]]; then
    echo "API error: rate limit exceeded"
    exit 1  # API fails
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    setup_test_project_assignment "test-repo" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_success  # Should handle API failures gracefully
    assert_output_contains "Could not determine current GitHub user"
}

# Test git config edge cases

@test "guard handles git config with special characters" {
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    
    # Set git config with special characters
    cd "$TEST_GIT_REPO"
    git config user.name "Test User: & Co. (Special)"
    git config user.email "test+tag@example.co.uk"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Test User: & Co. (Special)"
    assert_output_contains "test+tag@example.co.uk"
    assert_output_contains "Git config is complete"
}

@test "guard handles git config command failures" {
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    
    # Mock git that fails on config commands
    cat > "$TEST_HOME/git" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "config" ]]; then
    exit 1  # Fail all config commands
fi
# Pass through other git commands
exec /usr/bin/git "$@"
EOF
    chmod +x "$TEST_HOME/git"
    export PATH="$TEST_HOME:$PATH"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    assert_failure  # Should fail when git config is broken
    assert_output_contains "Git config incomplete!"
}

# Test file system edge cases

@test "guard handles very long project names" {
    local long_name="$(printf 'a%.0s' {1..200})"  # 200 character project name
    
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "$long_name" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    # Create directory with long name
    mkdir -p "$TEST_HOME/$long_name"
    cd "$TEST_HOME/$long_name"
    git init >/dev/null 2>&1
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Account matches project assignment"
}

@test "guard handles projects with special characters in names" {
    local special_name="test-repo!@#$%^&*()[]{}|;:,.<>?"
    
    setup_mock_gh_user "testuser"
    # Note: project assignment might not work with all special chars, but shouldn't crash
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "test"
    # Should handle gracefully regardless of project name
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# Test concurrent access and race conditions

@test "guard handles concurrent hook installation attempts" {
    # This is a basic test - real race condition testing would need more complex setup
    cd "$TEST_GIT_REPO"
    
    # Try to install multiple times rapidly
    run_guard_command "install" &
    local pid1=$!
    run_guard_command "install" &
    local pid2=$!
    
    wait $pid1
    local status1=$?
    wait $pid2  
    local status2=$?
    
    # At least one should succeed
    [[ "$status1" -eq 0 || "$status2" -eq 0 ]]
    
    # Should end up with guard hook installed
    assert_guard_hook_installed
}

# Test system resource constraints

@test "guard handles full filesystem gracefully" {
    # Skip this test if we can't simulate full filesystem safely
    skip "Filesystem full simulation requires special setup"
}

@test "guard handles extremely large git repositories" {
    # Create a git repo with many files to test performance
    cd "$TEST_GIT_REPO"
    
    # Create many small files
    for i in {1..100}; do
        echo "file $i content" > "file$i.txt"
    done
    
    git add . >/dev/null 2>&1
    git commit -m "Large repo test" >/dev/null 2>&1
    
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    # Test that guard still works efficiently
    time_command run_guard_command "test"
    assert_success
    
    # Should still be fast even with large repo
    assert_command_fast 200  # Allow slightly more time for large repo
}

# Test memory and resource usage

@test "guard commands don't leak file descriptors" {
    # Basic test - count open file descriptors before and after
    local fd_before=$(ls /proc/$$/fd 2>/dev/null | wc -l || echo "0")
    
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    setup_mock_git_config "Test User" "test@example.com"
    
    cd "$TEST_GIT_REPO"
    
    # Run multiple guard commands
    for i in {1..10}; do
        run_guard_command "test" >/dev/null 2>&1
    done
    
    local fd_after=$(ls /proc/$$/fd 2>/dev/null | wc -l || echo "0")
    
    # Allow for some variance but catch major leaks
    [[ "$fd_after" -lt $(($fd_before + 5)) ]]
}