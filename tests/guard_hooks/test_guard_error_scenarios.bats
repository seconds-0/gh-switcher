#!/usr/bin/env bats

# Essential error scenario tests - realistic failures only

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_guard_test_environment
}

teardown() {
    cleanup_guard_test_environment
}

# Realistic error conditions

@test "guard handles corrupted git repository" {
    rm -rf "$TEST_GIT_REPO/.git"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    assert_output_contains "Not in a git repository"
}

@test "guard handles malformed project configuration" {
    echo "invalid-format-line" > "$GH_PROJECT_CONFIG"
    echo "=missing-project-name" >> "$GH_PROJECT_CONFIG"
    
    setup_mock_gh_user "testuser"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_success  # Should handle gracefully
    assert_output_contains "No project assignment found"
}

@test "guard handles missing project configuration file" {
    rm -f "$GH_PROJECT_CONFIG"
    
    setup_mock_gh_user "testuser"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "No project assignment found"
}

@test "guard handles gh API failures gracefully" {
    # Mock gh that fails on API calls
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then
    exit 0
elif [[ "$1 $2 $3" == "api user --jq" ]]; then
    echo "API error: rate limit exceeded" >&2
    exit 1
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    setup_test_project_assignment "test-repo" "testuser"
    cd "$TEST_GIT_REPO"
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "GitHub CLI not authenticated"
}

@test "guard handles git config with special characters" {
    setup_mock_gh_user "testuser"
    setup_test_project_assignment "test-repo" "testuser"
    
    cd "$TEST_GIT_REPO"
    git config user.name "Test User: & Co."
    git config user.email "test+tag@example.co.uk"
    
    run_guard_command "test"
    assert_success
    assert_output_contains "Test User: & Co."
    assert_output_contains "test+tag@example.co.uk"
}