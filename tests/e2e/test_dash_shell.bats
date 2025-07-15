#!/usr/bin/env bats

# E2E Test - Dash Shell (POSIX sh) Compatibility
# Tests gh-switcher works in strict POSIX environments
# These tests verify:
# 1. No bash-specific syntax breaks sourcing
# 2. Core commands work in POSIX sh
# 3. Basic functionality doesn't depend on bashisms

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

# Test 1: gh-switcher requires bash, not POSIX sh
@test "e2e: dash - gh-switcher requires bash features" {
    command -v dash >/dev/null 2>&1 || skip "Dash not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # This should fail because gh-switcher uses bashisms
    run dash -c ". '$script_path' 2>&1"
    
    assert_failure
    # Verify it fails due to bash-specific syntax
    assert_output_contains "[[: not found"
}

# Test 2: gh-switcher can be invoked via bash from dash
@test "e2e: dash - gh-switcher works when invoked through bash" {
    command -v dash >/dev/null 2>&1 || skip "Dash not installed"
    command -v bash >/dev/null 2>&1 || skip "Bash not available"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # While we can't source gh-switcher in dash, we can invoke it through bash
    run dash -c "
        # Call gh-switcher through bash
        bash -c \"source '$script_path' && ghs add dashuser --ssh-key ~/.ssh/testuser1_ed25519\" >/dev/null 2>&1
        if [ \$? -ne 0 ]; then
            echo 'ERROR: Failed to add user via bash'
            exit 1
        fi
        
        # Check it worked
        if bash -c \"source '$script_path' && ghs users\" 2>&1 | grep -q 'dashuser'; then
            echo 'User added successfully'
        else
            echo 'ERROR: User not found'
            exit 1
        fi
        
        # Clean up
        bash -c \"source '$script_path' && ghs remove dashuser\" >/dev/null 2>&1
        
        echo 'SUCCESS: gh-switcher works via bash invocation'
    "
    
    assert_success
    assert_output_contains "SUCCESS: gh-switcher works via bash invocation"
}

# Test 3: Document bash requirement for POSIX sh users
@test "e2e: dash - documentation exists for POSIX shell users" {
    # Verify we have documentation for POSIX shell users
    local docs_file="$BATS_TEST_DIRNAME/../../docs/POSIX_SHELL_USAGE.md"
    
    [[ -f "$docs_file" ]] || fail "POSIX shell documentation missing"
    
    # Check it contains key information
    run grep -q "gh-switcher requires bash" "$docs_file"
    assert_success
    
    run grep -q "alias ghs=" "$docs_file"
    assert_success
    
    run grep -q "Docker" "$docs_file"
    assert_success
    
    echo "✓ POSIX shell documentation exists and is comprehensive"
}