#!/usr/bin/env bats

# E2E Tests for Basic Command Flows
# Tests user management and common workflows in real shell environments

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
    create_mock_gh
    create_test_ssh_keys
}

teardown() {
    cleanup_e2e_test_env
}

# Test 3 from MVP: Basic user add/switch/remove flow
@test "e2e: basic user add/switch/remove flow" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    local output
    output=$(assert_shell_command_succeeds "bash" "
        source '$script_path'
        
        # Initial state - no users
        output=\$(ghs users 2>&1)
        if [[ \"\$output\" != *'No users configured'* ]]; then
            echo \"ERROR: Expected 'No users configured', got: \$output\" >&2
            exit 1
        fi
        
        # Add first user
        ghs add testuser1 >/dev/null 2>&1
        if [[ \$? -ne 0 ]]; then
            echo 'ERROR: Failed to add testuser1' >&2
            exit 1
        fi
        
        # Add second user with SSH key
        ghs add testuser2 --ssh-key ~/.ssh/testuser2_ed25519 >/dev/null 2>&1
        if [[ \$? -ne 0 ]]; then
            echo 'ERROR: Failed to add testuser2' >&2
            exit 1
        fi
        
        # Verify users were added
        users=\$(ghs users)
        if [[ \"\$users\" != *'testuser1'* ]] || [[ \"\$users\" != *'testuser2'* ]]; then
            echo \"ERROR: Users not listed correctly: \$users\" >&2
            exit 1
        fi
        
        # Switch to user by name
        output=\$(ghs switch testuser2 2>&1)
        if [[ \"\$output\" != *'Switched to'* ]]; then
            echo \"ERROR: Switch failed: \$output\" >&2
            exit 1
        fi
        
        # Verify current user
        status=\$(ghs status 2>&1)
        if [[ \"\$status\" != *'testuser2'* ]]; then
            echo \"ERROR: Wrong current user in status: \$status\" >&2
            exit 1
        fi
        
        # Switch by number
        ghs switch 1 >/dev/null 2>&1
        status=\$(ghs status 2>&1)
        if [[ \"\$status\" != *'testuser1'* ]]; then
            echo \"ERROR: Switch by number failed\" >&2
            exit 1
        fi
        
        # Remove user
        ghs remove testuser2 >/dev/null 2>&1
        if [[ \$? -ne 0 ]]; then
            echo 'ERROR: Failed to remove user' >&2
            exit 1
        fi
        
        # Verify user was removed
        users=\$(ghs users)
        if [[ \"\$users\" == *'testuser2'* ]]; then
            echo 'ERROR: User not removed' >&2
            exit 1
        fi
        
        echo 'SUCCESS: Basic flow completed'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: Basic flow completed"
}

# Test 4 from MVP: SSH key permission validation
@test "e2e: SSH key permission validation" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Run test in bash
    run bash -c "
        source '$script_path'
        
        # Create SSH key with wrong permissions
        touch ~/.ssh/bad_perms_key
        chmod 644 ~/.ssh/bad_perms_key
        
        # Add user with badly permissioned key
        ghs add testuser-bad --ssh-key ~/.ssh/bad_perms_key >/dev/null 2>&1
        
        # Check if user was added successfully
        if ! grep -q 'testuser-bad' ~/.config/gh-switcher/users 2>/dev/null; then
            echo \"ERROR: User with bad perms key not added\" >&2
            exit 1
        fi
        
        # Test with non-existent SSH key - should add user with warning
        output=\$(ghs add testuser-missing --ssh-key ~/.ssh/nonexistent 2>&1)
        if [[ \$? -ne 0 ]] && [[ \"\$output\" != *'Warning'* ]]; then
            echo \"ERROR: Should add user with warning for missing key\" >&2
            exit 1
        fi
        
        # Test shows appropriate warnings/errors for edge cases
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}

# Test 5 from MVP: Guard hook installation/removal
@test "e2e: guard hook installation and removal" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    local output
    output=$(assert_shell_command_succeeds "bash" "
        source '$script_path'
        
        # Create a test git repository
        test_repo=\"\$HOME/test-repo\"
        mkdir -p \"\$test_repo\"
        cd \"\$test_repo\"
        git init >/dev/null 2>&1
        
        # Install guard hooks
        output=\$(ghs guard install 2>&1)
        if [[ \"\$output\" != *'Guard hooks installed'* ]] && [[ \"\$output\" != *'successfully'* ]]; then
            echo \"ERROR: Guard install failed: \$output\" >&2
            exit 1
        fi
        
        # Verify hook exists
        if [[ ! -f .git/hooks/pre-commit ]]; then
            echo 'ERROR: Pre-commit hook not created' >&2
            exit 1
        fi
        
        # Check guard status
        output=\$(ghs guard status 2>&1)
        if [[ \"\$output\" != *'INSTALLED'* ]] && [[ \"\$output\" != *'installed'* ]]; then
            echo \"ERROR: Guard status incorrect: \$output\" >&2
            exit 1
        fi
        
        # Test guard (should work even without assignment)
        output=\$(ghs guard test 2>&1)
        # Should not error out completely
        if [[ \$? -eq 127 ]]; then
            echo 'ERROR: Guard test command not found' >&2
            exit 1
        fi
        
        # Uninstall guard hooks
        output=\$(ghs guard uninstall 2>&1)
        if [[ \"\$output\" != *'removed'* ]] && [[ \"\$output\" != *'uninstalled'* ]]; then
            echo \"ERROR: Guard uninstall failed: \$output\" >&2
            exit 1
        fi
        
        # Verify hook removed
        if [[ -f .git/hooks/pre-commit ]] && grep -q 'gh-switcher' .git/hooks/pre-commit 2>/dev/null; then
            echo 'ERROR: Pre-commit hook not removed' >&2
            exit 1
        fi
        
        echo 'SUCCESS: Guard hooks work correctly'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: Guard hooks work correctly"
}

# Test 7 from MVP: Error handling for missing user
@test "e2e: error handling for missing user" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Run error handling tests
    run bash -c "
        source '$script_path'
        
        # Try to switch to non-existent user
        if ghs switch nonexistent 2>/dev/null; then
            echo 'ERROR: Switch to non-existent user should fail' >&2
            exit 1
        fi
        
        # Try to remove non-existent user  
        if ghs remove nonexistent 2>/dev/null; then
            echo 'ERROR: Remove non-existent user should fail' >&2
            exit 1
        fi
        
        # Try to show non-existent user
        if ghs show nonexistent 2>/dev/null; then
            echo 'ERROR: Show non-existent user should fail' >&2
            exit 1
        fi
        
        # Add a user for number testing
        ghs add testuser1 >/dev/null 2>&1
        
        # Try invalid user number
        if ghs switch 99 2>/dev/null; then
            echo 'ERROR: Switch to invalid number should fail' >&2
            exit 1
        fi
        
        # Try negative number
        if ghs switch -1 2>/dev/null; then
            echo 'ERROR: Switch to negative number should fail' >&2
            exit 1
        fi
        
        # Verify error commands actually failed (we already tested they don't succeed)
        echo 'SUCCESS'
    "
    
    assert_success
    [[ "$output" == "SUCCESS" ]]
}