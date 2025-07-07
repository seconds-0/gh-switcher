#!/usr/bin/env bash

# Main test helper for gh-switcher testing
# Provides common utilities and setup for all tests

# Set up test environment isolation
setup_test_environment() {
    # Create isolated test environment
    export TEST_HOME="$BATS_TMPDIR/gh-switcher-test-$$"
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"
    
    # Override gh-switcher config paths to use test environment
    export GH_PROJECT_CONFIG="$TEST_HOME/.gh-project-accounts"
    export GH_USERS_CONFIG="$TEST_HOME/.gh-users"
    export GH_USER_PROFILES="$TEST_HOME/.gh-user-profiles"
    
    # Create test home directory
    mkdir -p "$TEST_HOME"
    
    # Source the gh-switcher script for function access
    source "$BATS_TEST_DIRNAME/../gh-switcher.sh"
}

# Clean up test environment
cleanup_test_environment() {
    if [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
    fi
    
    # Restore original HOME
    if [[ -n "$ORIGINAL_HOME" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

# Custom assertions for gh-switcher testing

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "Expected file to exist: $file"
        return 1
    }
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    [[ ! -f "$file" ]] || {
        echo "Expected file to not exist: $file"
        return 1
    }
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        echo "Expected directory to exist: $dir"
        return 1
    }
}

# Assert that a user exists in the users file
assert_user_exists() {
    local username="$1"
    assert_file_exists "$GH_USERS_CONFIG"
    grep -q "^$username$" "$GH_USERS_CONFIG" || {
        echo "Expected user to exist in users file: $username"
        return 1
    }
}

# Assert that a user does not exist in the users file
assert_user_not_exists() {
    local username="$1"
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        ! grep -q "^$username$" "$GH_USERS_CONFIG" || {
            echo "Expected user to not exist in users file: $username"
            return 1
        }
    fi
}

# Assert that a profile exists for a user
assert_profile_exists() {
    local username="$1"
    local profile
    profile=$(get_user_profile "$username" 2>/dev/null)
    [[ $? -eq 0 ]] || {
        echo "Expected profile to exist for user: $username"
        debug_test_state
        return 1
    }
}

# Assert that a profile has specific SSH key
assert_profile_has_ssh_key() {
    local username="$1"
    local expected_ssh_key="$2"
    local profile
    profile=$(get_user_profile "$username")
    [[ $? -eq 0 ]] || {
        echo "Profile does not exist for user: $username"
        return 1
    }
    
    local ssh_key_path
    ssh_key_path=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    [[ "$ssh_key_path" == "$expected_ssh_key" ]] || {
        echo "Expected SSH key '$expected_ssh_key', got '$ssh_key_path'"
        return 1
    }
}

# Assert that a profile does not have SSH key (HTTPS mode)
assert_profile_has_no_ssh_key() {
    local username="$1"
    local profile
    profile=$(get_user_profile "$username")
    [[ $? -eq 0 ]] || {
        echo "Profile does not exist for user: $username"
        return 1
    }
    
    local ssh_key_path
    ssh_key_path=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    [[ -z "$ssh_key_path" ]] || {
        echo "Expected no SSH key, but found: $ssh_key_path"
        return 1
    }
}

# Assert that git config is set to specific value
assert_git_config_set() {
    local config_key="$1"
    local expected_pattern="$2"
    local actual_value
    
    actual_value=$(git config --get "$config_key" 2>/dev/null || echo "")
    [[ "$actual_value" == $expected_pattern ]] || {
        echo "Expected git config '$config_key' to match '$expected_pattern', got '$actual_value'"
        return 1
    }
}

# Assert that git config is not set
assert_git_config_unset() {
    local config_key="$1"
    local actual_value
    
    actual_value=$(git config --get "$config_key" 2>/dev/null || echo "")
    [[ -z "$actual_value" ]] || {
        echo "Expected git config '$config_key' to be unset, but got '$actual_value'"
        return 1
    }
}

# Assert that output contains specific text
assert_output_contains() {
    local expected="$1"
    [[ "$output" == *"$expected"* ]] || {
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    }
}

# Assert that output does not contain specific text
assert_output_not_contains() {
    local unexpected="$1"
    [[ "$output" != *"$unexpected"* ]] || {
        echo "Expected output to not contain: $unexpected"
        echo "Actual output: $output"
        return 1
    }
}

# Assert that command succeeded (exit code 0)
assert_success() {
    [[ "$status" -eq 0 ]] || {
        echo "Expected command to succeed (exit code 0), got $status"
        echo "Output: $output"
        return 1
    }
}

# Assert that command failed (non-zero exit code)
assert_failure() {
    [[ "$status" -ne 0 ]] || {
        echo "Expected command to fail (non-zero exit code), got $status"
        echo "Output: $output"
        return 1
    }
}

# Debug helper to print current test state
debug_test_state() {
    echo "=== TEST STATE DEBUG ==="
    echo "TEST_HOME: $TEST_HOME"
    echo "GH_USERS_CONFIG: $GH_USERS_CONFIG"
    echo "GH_USER_PROFILES: $GH_USER_PROFILES"
    echo "GH_PROJECT_CONFIG: $GH_PROJECT_CONFIG"
    
    if [[ -f "$GH_USERS_CONFIG" ]]; then
        echo "Users file contents:"
        cat "$GH_USERS_CONFIG" || echo "  (empty or unreadable)"
    else
        echo "Users file does not exist"
    fi
    
    if [[ -f "$GH_USER_PROFILES" ]]; then
        echo "Profiles file contents:"
        cat "$GH_USER_PROFILES" || echo "  (empty or unreadable)"
    else
        echo "Profiles file does not exist"
    fi
    
    echo "========================"
}