#!/usr/bin/env bats

# E2E Tests for Shell Sourcing and Compatibility
# These tests run gh-switcher in real shell environments to catch shell-specific bugs

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
}

teardown() {
    cleanup_e2e_test_env
}

# Test 1: THE CRITICAL TEST - Would have caught the zsh PATH bug
@test "e2e: zsh sources gh-switcher without breaking PATH" {
    if ! shell_available "zsh"; then
        skip "zsh not available"
    fi
    
    # Get the absolute path to gh-switcher.sh
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # This test specifically checks for the PATH preservation bug
    local output
    output=$(assert_shell_command_succeeds "zsh" "
        # Capture original PATH
        original_path=\"\$PATH\"
        
        # Source gh-switcher
        source '$script_path'
        
        # Verify PATH still contains critical directories
        if [[ \"\$PATH\" != *\"/usr/bin\"* ]]; then
            echo 'ERROR: PATH missing /usr/bin' >&2
            exit 1
        fi
        
        if [[ \"\$PATH\" != *\"/bin\"* ]]; then
            echo 'ERROR: PATH missing /bin' >&2
            exit 1
        fi
        
        # Verify PATH wasn't completely replaced
        if [[ \"\$PATH\" == \"/tmp\" || \"\$PATH\" == \"\" ]]; then
            echo 'ERROR: PATH was overwritten' >&2
            exit 1
        fi
        
        # Verify critical commands still work
        command -v grep >/dev/null || { echo 'ERROR: grep not found' >&2; exit 1; }
        command -v sed >/dev/null || { echo 'ERROR: sed not found' >&2; exit 1; }
        
        # Verify ghs function is available
        type ghs >/dev/null 2>&1 || { echo 'ERROR: ghs function not defined' >&2; exit 1; }
        
        echo 'SUCCESS: PATH preserved correctly'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: PATH preserved correctly"
}

# Test 2: Bash compatibility - basic sourcing
@test "e2e: bash sources gh-switcher without errors" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    local output
    output=$(assert_shell_command_succeeds "bash" "
        source '$script_path'
        
        # Verify ghs function exists
        type ghs >/dev/null 2>&1 || { echo 'ERROR: ghs function not defined' >&2; exit 1; }
        
        # Verify function is callable
        ghs help >/dev/null 2>&1 || { echo 'ERROR: ghs help failed' >&2; exit 1; }
        
        echo 'SUCCESS: bash sourcing works'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: bash sourcing works"
}

# Test 3: Multiple sourcing - readonly variable errors
@test "e2e: multiple sourcing doesn't fail on readonly variables" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Test in bash first
    local output
    output=$(assert_shell_command_succeeds "bash" "
        source '$script_path'
        source '$script_path'  # Second source should not fail
        source '$script_path'  # Third source should not fail
        
        echo 'SUCCESS: multiple sourcing works'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: multiple sourcing works"
    
    # Also test in zsh if available
    if shell_available "zsh"; then
        output=$(assert_shell_command_succeeds "zsh" "
            source '$script_path'
            source '$script_path'  # Second source should not fail
            
            echo 'SUCCESS: zsh multiple sourcing works'
        ")
        
        assert_success
        assert_output_contains "SUCCESS: zsh multiple sourcing works"
    fi
}

# Test 4: Shell startup performance
@test "e2e: shell sources gh-switcher within 300ms" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Test bash startup time
    local output
    output=$(assert_shell_command_succeeds "bash" "
        # Get start time in milliseconds (portable across macOS and Linux)
        if command -v python3 >/dev/null 2>&1; then
            start_time=\$(python3 -c 'import time; print(int(time.time() * 1000))')
        elif command -v perl >/dev/null 2>&1; then
            start_time=\$(perl -MTime::HiRes=time -e 'print int(time * 1000)')
        else
            # Fallback to seconds precision
            start_time=\$(date +%s)000
        fi
        
        source '$script_path'
        
        # Get end time in milliseconds
        if command -v python3 >/dev/null 2>&1; then
            end_time=\$(python3 -c 'import time; print(int(time.time() * 1000))')
        elif command -v perl >/dev/null 2>&1; then
            end_time=\$(perl -MTime::HiRes=time -e 'print int(time * 1000)')
        else
            # Fallback to seconds precision
            end_time=\$(date +%s)000
        fi
        
        # Calculate duration in milliseconds
        duration_ms=\$((end_time - start_time))
        
        echo \"Duration: \${duration_ms}ms\"
        
        # Check if under 300ms
        if [[ \$duration_ms -lt 300 ]]; then
            echo 'SUCCESS: Fast startup'
        else
            echo 'ERROR: Slow startup' >&2
            exit 1
        fi
    ")
    
    assert_success
    assert_output_contains "SUCCESS: Fast startup"
}

# Test 5: Environment isolation - only expected variables
@test "e2e: gh-switcher only sets expected environment variables" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    local output
    output=$(assert_shell_command_succeeds "bash" "
        # Source gh-switcher
        source '$script_path'
        
        # Check that only expected variables are set
        # We expect: GH_USERS_CONFIG, GH_USER_PROFILES, GH_PROJECT_CONFIG
        env | grep '^GH_' | sort > /tmp/gh_vars
        
        expected_vars=(
            'GH_PROJECT_CONFIG='
            'GH_USERS_CONFIG='
            'GH_USER_PROFILES='
        )
        
        # Verify each expected variable exists
        for var in \"\${expected_vars[@]}\"; do
            if ! grep -q \"^\$var\" /tmp/gh_vars; then
                echo \"ERROR: Missing expected variable: \$var\" >&2
                exit 1
            fi
        done
        
        # Check for unexpected GH_ variables
        unexpected=\$(grep '^GH_' /tmp/gh_vars | grep -v -E '^(GH_PROJECT_CONFIG|GH_USERS_CONFIG|GH_USER_PROFILES)=' || true)
        if [[ -n \"\$unexpected\" ]]; then
            echo \"ERROR: Unexpected GH_ variables:\" >&2
            echo \"\$unexpected\" >&2
            exit 1
        fi
        
        echo 'SUCCESS: Only expected variables set'
    ")
    
    assert_success
    assert_output_contains "SUCCESS: Only expected variables set"
}

# Test 6: Verify the actual bug scenario - ghs assign in zsh
@test "e2e: zsh ghs assign command works (original bug scenario)" {
    if ! shell_available "zsh"; then
        skip "zsh not available"
    fi
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create mock gh for this test
    create_mock_gh
    
    local output
    output=$(run_in_shell "zsh" "
        source '$script_path'
        
        # Verify ghs is available
        type ghs >/dev/null || exit 1
        
        # Add a test user directly (not interactive)
        ghs add testuser1 >/dev/null 2>&1 || true
        
        # The key test: can we run ghs assign without PATH errors?
        cd /tmp
        # We expect this to fail (no git repo) but NOT with 'command not found'
        ghs assign 1 2>&1 || true
    ")
    
    # The command should not fail with "command not found" errors
    if [[ "$output" == *"command not found"* ]]; then
        echo "Output: $output" >&2
        fail "ghs assign failed with command not found - PATH bug still present"
    fi
    
    # It's OK if it fails for other reasons (no git repo, etc)
    # We just want to ensure commands are found
    assert_output_not_contains "command not found"
}