#!/usr/bin/env bats

load '../helpers/test_helper'
load '../helpers/guard_helper'

setup() {
    setup_test_environment
    
    # Mock gh command
    setup_mock_gh_user "testuser"
}

teardown() {
    cleanup_test_environment
}

@test "full workflow: add, show, edit, switch" {
    # Add user
    run ghs add testuser
    assert_success
    
    # Show initial state
    run ghs show testuser
    assert_success
    assert_output_contains "Email: testuser@users.noreply.github.com"
    
    # Edit email
    run ghs edit testuser --email test@company.com
    assert_success
    
    # Verify change
    run ghs show testuser
    assert_success
    assert_output_contains "Email: test@company.com"
    
    # Switch should work (in test environment)
    run ghs switch testuser
    assert_success
}

@test "pre-flight check in switch command" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	/missing/key	github.com" >> "$GH_USER_PROFILES"
    
    # Create a test git repo
    mkdir -p "$TEST_HOME/test-repo"
    cd "$TEST_HOME/test-repo"
    git init >/dev/null 2>&1
    
    # Mock user input to say 'n'
    run bash -c "echo 'n' | '$BATS_TEST_DIRNAME/../../gh-switcher.sh' switch alice"
    assert_failure
    assert_output_contains "SSH key not found"
    assert_output_contains "Continue anyway?"
}

@test "status command shows assigned user" {
    # Create a test git repo
    local project="test-project"
    mkdir -p "$TEST_HOME/$project"
    cd "$TEST_HOME/$project"
    git init >/dev/null 2>&1
    
    # Setup project assignment
    echo "$project=alice" >> "$GH_PROJECT_CONFIG"
    
    # Create user with missing SSH
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	/missing/key	github.com" >> "$GH_USER_PROFILES"
    
    run ghs status
    assert_success
    assert_output_contains "alice"
    assert_output_contains "<assigned>"
    # Profile warnings are shown in 'ghs show', not in status
}

@test "status shows user without profile" {
    # Create a test git repo
    local project="test-project"
    mkdir -p "$TEST_HOME/$project"
    cd "$TEST_HOME/$project"
    git init >/dev/null 2>&1
    
    # Setup project assignment
    echo "$project=bob" >> "$GH_PROJECT_CONFIG"
    
    # Create user without profile
    echo "bob" >> "$GH_USERS_CONFIG"
    
    run ghs status
    assert_success
    assert_output_contains "bob"
    assert_output_contains "<assigned>"
    # Profile details are shown in 'ghs show', not in status
}

@test "show command detects git config mismatch for active user" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    # Mock gh to return alice as current user
    function gh() {
        if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
            echo "alice"
        fi
    }
    export -f gh
    
    # Mock git config to return different email
    function git() {
        if [[ "$1 $2 $3" == "config --global user.email" ]]; then
            echo "different@example.com"
        fi
    }
    export -f git
    
    run ghs show alice
    assert_success
    assert_output_contains "Git email doesn't match profile"
    assert_output_contains "different@example.com"
    assert_output_contains "ghs switch alice"
}

@test "edit suggests reapply for active user" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    # Mock gh to return alice as current user
    function gh() {
        if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
            echo "alice"
        fi
    }
    export -f gh
    
    run ghs edit alice --email alice@newcompany.com
    assert_success
    assert_output_contains "Profile updated"
    assert_output_contains "Run 'ghs switch alice' to apply changes"
}

@test "dispatcher handles new commands" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    # Test show command
    run ghs show alice
    assert_success
    
    # Test profile alias
    run ghs profile alice
    assert_success
    
    # Test edit command
    run ghs edit alice --name "Alice Smith"
    assert_success
}

@test "help shows new commands" {
    run ghs help
    assert_success
    assert_output_contains "show <user>"
    assert_output_contains "View account details and diagnose issues"
    assert_output_contains "edit <user>"
    assert_output_contains "Update email, SSH key, or host settings"
    assert_output_contains "[NEW]"
}

@test "multiple SSH key suggestions prioritize username matches" {
    echo "work" >> "$GH_USERS_CONFIG"
    echo "work	Work	work@company.com	$TEST_HOME/.ssh/old_work	github.com" >> "$GH_USER_PROFILES"
    
    # Create various SSH keys
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/id_rsa"
    touch "$TEST_HOME/.ssh/id_ed25519"
    touch "$TEST_HOME/.ssh/id_rsa_work"
    touch "$TEST_HOME/.ssh/work"
    
    run ghs show work
    assert_success
    assert_output_contains "SSH key not found"
    # Should show work-related keys with proper annotation
    assert_output_contains "work (matches username)"
}

@test "email typo detection skips bot accounts" {
    echo "dependabot" >> "$GH_USERS_CONFIG"
    echo "dependabot	Bot	dependabot@github.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs show dependabot
    assert_success
    # Should not show email typo warning for bot
    assert_output_not_contains "Possible typo"
    assert_output_contains "No issues detected"
}

@test "complete first-time user flow with current" {
    # Given - mock gh authenticated as newuser
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
    echo "newuser"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    # Create a test git repo for switching
    mkdir -p "$TEST_HOME/project"
    cd "$TEST_HOME/project"
    git init >/dev/null 2>&1
    
    # When - First time user flow
    # 1. Add current user
    run ghs add current
    assert_success
    assert_output_contains "Found: newuser"
    assert_output_contains "Added newuser"
    
    # 2. Verify user was added
    run ghs users
    assert_success
    assert_output_contains "newuser"
    
    # 3. Switch to the user
    run ghs switch newuser
    assert_success
    assert_output_contains "Switched to user: newuser"
    
    # 4. Verify git config was set
    run git config user.name
    assert_success
    [[ "$output" == "newuser" ]]
    
    # 5. Verify status shows correct user
    run ghs status
    assert_success
    assert_output_contains "Current project: project"
}

@test "invalid commands don't corrupt terminal" {
    # Test that previously problematic inputs don't blow up the terminal
    # This is a regression test for the bug where 'ghs 1' nuked the terminal
    
    # Numeric input (the original bug)
    run ghs 1
    assert_failure
    assert_output_contains "Unknown command"
    
    # Command injection attempt
    run ghs "; echo hacked"
    assert_failure
    assert_output_contains "Unknown command"
    
    # Special characters that could mess up terminal
    run ghs '$USER'
    assert_failure
    assert_output_contains "Unknown command"
    
    # Very long input
    run ghs "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    assert_failure
    assert_output_contains "Unknown command"
    
    # Empty after sanitization (emoji)
    run ghs "🚀"
    assert_failure
    assert_output_contains "Unknown command"
}