#!/usr/bin/env bats

# E2E Test - Fish Shell Environment
# Tests gh-switcher wrapper function in Fish shell

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
    create_mock_gh
    create_test_ssh_keys
}

teardown() {
    cleanup_e2e_test_env
    # Clean up Fish functions if they exist
    rm -f ~/.config/fish/functions/ghs.fish
}

# Test 1: Wrapper function provides ghs command in Fish
@test "e2e: fish - wrapper function provides ghs command" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function with correct path
    mkdir -p ~/.config/fish/functions
    cat > ~/.config/fish/functions/ghs.fish << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test wrapper function works
    run fish -c "ghs status"
    
    assert_success
    # Should show status output (either "No current user" or actual user)
    assert_output_contains "Current GitHub user:" || assert_output_contains "No current user"
}

# Test 2: User switching persists between Fish and Bash
@test "e2e: fish - switches persist between fish and bash" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p ~/.config/fish/functions
    cat > ~/.config/fish/functions/ghs.fish << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Add and switch user in bash first
    run bash -c "
        source '$script_path'
        ghs add fishtestuser >/dev/null 2>&1
        ghs switch fishtestuser
    "
    assert_success
    
    # Verify switch persisted in fish
    run fish -c "ghs status"
    assert_success
    assert_output_contains "fishtestuser"
    
    # Clean up
    run bash -c "source '$script_path' && ghs remove fishtestuser"
}

# Test 3: Git operations work after switching in Fish
@test "e2e: fish - git operations work after switching" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p ~/.config/fish/functions
    cat > ~/.config/fish/functions/ghs.fish << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Create a test git repo
    local test_repo
    test_repo=$(mktemp -d)
    
    run fish -c "
        cd '$test_repo'
        git init >/dev/null 2>&1
        
        # Add user with profile
        ghs add fishuser >/dev/null 2>&1
        ghs edit fishuser --name 'Fish User' --email 'fish@test.com' >/dev/null 2>&1
        
        # Switch to user
        ghs switch fishuser >/dev/null 2>&1
        
        # Check git config was updated
        set git_name (git config user.name)
        set git_email (git config user.email)
        
        if test \"\$git_name\" != 'Fish User'
            echo \"ERROR: Git name not set correctly: \$git_name\" >&2
            exit 1
        end
        
        if test \"\$git_email\" != 'fish@test.com'
            echo \"ERROR: Git email not set correctly: \$git_email\" >&2
            exit 1
        end
        
        echo 'SUCCESS: Git config updated correctly'
    "
    
    assert_success
    assert_output_contains "SUCCESS: Git config updated correctly"
    
    # Clean up
    rm -rf "$test_repo"
    run bash -c "source '$script_path' && ghs remove fishuser"
}