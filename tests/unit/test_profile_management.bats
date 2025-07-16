#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

# Helper to measure command execution time in milliseconds
measure_time_ms() {
    local start_ns=$(date +%s%N 2>/dev/null || echo "0")
    if [[ "$start_ns" == "0" ]]; then
        # macOS doesn't support nanoseconds, use python
        local start_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
        "$@" >/dev/null 2>&1
        local end_ms=$(python3 -c 'import time; print(int(time.time() * 1000))')
        echo $((end_ms - start_ms))
    else
        # Linux supports nanoseconds
        "$@" >/dev/null 2>&1
        local end_ns=$(date +%s%N)
        echo $(( (end_ns - start_ns) / 1000000 ))
    fi
}

# Show command tests
@test "ghs show displays profile information" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice Smith	alice@example.com	$TEST_HOME/.ssh/alice_key	github.com" >> "$GH_USER_PROFILES"
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/alice_key"
    chmod 600 "$TEST_HOME/.ssh/alice_key"
    
    run ghs show alice
    assert_success
    assert_output_contains "👤 alice"
    assert_output_contains "Email: alice@example.com"
    assert_output_contains "Name: Alice Smith"
    # SSH path should show with proper permissions icon
    if [[ "$OSTYPE" == "msys" ]]; then
        assert_output_contains ".ssh/alice_key [OK]"
    else
        assert_output_contains ".ssh/alice_key ✅"
    fi
}

@test "ghs show works with user ID" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs show 1
    assert_success
    assert_output_contains "👤 alice"
}

@test "ghs show detects missing SSH key" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	$TEST_HOME/.ssh/missing	github.com" >> "$GH_USER_PROFILES"
    
    run ghs show alice
    assert_success
    assert_output_contains ".ssh/missing ❌"
    assert_output_contains "SSH key not found"
}

@test "ghs show finds alternative SSH keys" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	$TEST_HOME/.ssh/old_key	github.com" >> "$GH_USER_PROFILES"
    
    # Create alternative keys
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/id_ed25519_alice"
    touch "$TEST_HOME/.ssh/id_rsa"
    
    run ghs show alice
    assert_success
    assert_output_contains "Found 2 SSH keys that might work"
    assert_output_contains "id_ed25519_alice (matches username)"
    assert_output_contains "ghs edit alice --ssh-key"
}

@test "ghs show detects permission issues" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	$TEST_HOME/.ssh/alice_key	github.com" >> "$GH_USER_PROFILES"
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/alice_key"
    chmod 644 "$TEST_HOME/.ssh/alice_key"
    
    run ghs show alice
    assert_success
    assert_output_contains "SSH key has incorrect permissions: 644"
    assert_output_contains "chmod 600"
}

@test "ghs show detects email typo" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@github.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs show alice
    assert_success
    assert_output_contains "Possible typo in email"
    assert_output_contains "alice@users.noreply.github.com"
}

@test "ghs show handles missing profile" {
    echo "alice" >> "$GH_USERS_CONFIG"
    
    run ghs show alice
    assert_failure
    assert_output_contains "No profile for alice"
    assert_output_contains "ghs edit alice --email"
}

@test "ghs show handles non-existent user" {
    run ghs show nonexistent
    assert_failure
    assert_output_contains "User 'nonexistent' not found"
}

# Edit command tests
@test "ghs edit updates email" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	old@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --email new@example.com
    assert_success
    assert_output_contains "Profile updated"
    
    run ghs show alice
    assert_output_contains "Email: new@example.com"
}

@test "ghs edit updates name" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Old Name	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --name "New Name"
    assert_success
    
    run ghs show alice
    assert_output_contains "Name: New Name"
}

@test "ghs edit removes SSH key with none" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	/ssh/key	github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --ssh-key none
    assert_success
    
    run ghs show alice
    assert_output_contains "SSH: Using HTTPS"
}

@test "ghs edit expands tilde in paths" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    mkdir -p "$TEST_HOME/.ssh"
    # Create a mock SSH key with minimal valid content
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$TEST_HOME/.ssh/key"
    echo "mock key content" >> "$TEST_HOME/.ssh/key"
    echo "-----END OPENSSH PRIVATE KEY-----" >> "$TEST_HOME/.ssh/key"
    chmod 600 "$TEST_HOME/.ssh/key"
    
    # Need to set HOME for tilde expansion
    HOME="$TEST_HOME" run ghs edit alice --ssh-key "~/.ssh/key"
    assert_success
    
    # Check expanded path
    local profile
    profile=$(grep "^alice	" "$GH_USER_PROFILES")
    [[ "$profile" =~ "$TEST_HOME/.ssh/key" ]]
}

@test "ghs edit rejects GPG options" {
    echo "alice" >> "$GH_USERS_CONFIG"
    
    run ghs edit alice --gpg-key somekey
    assert_failure
    assert_output_contains "GPG commit signing is not currently supported"
}

@test "ghs edit with no changes shows current" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice
    assert_success
    assert_output_contains "No changes specified"
    assert_output_contains "👤 alice"
}

@test "ghs edit validates email format" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --email "invalid-email"
    assert_failure
    assert_output_contains "Invalid email format"
}

@test "ghs edit validates SSH key exists" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --ssh-key "/nonexistent/key"
    assert_failure
    assert_output_contains "SSH key not found"
}

@test "ghs edit creates profile if missing" {
    echo "alice" >> "$GH_USERS_CONFIG"
    
    run ghs edit alice --email alice@test.com
    assert_success
    assert_output_contains "No profile found, creating new one"
    assert_output_contains "Profile updated"
}

@test "ghs edit handles multiple changes" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com		github.com" >> "$GH_USER_PROFILES"
    
    run ghs edit alice --name "Alice Smith" --email alice@company.com
    assert_success
    
    run ghs show alice
    assert_output_contains "Name: Alice Smith"
    assert_output_contains "Email: alice@company.com"
}

# Performance tests
@test "ghs show completes within reasonable time" {
    echo "perfuser" >> "$GH_USERS_CONFIG"
    echo "perfuser	Test	test@example.com		github.com" >> "$GH_USER_PROFILES"
    
    local duration=$(measure_time_ms ghs show perfuser)
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 300ms for bash script startup overhead in CI environments
    local timeout=$(get_timeout_ms 300)
    [[ "$duration" -lt "$timeout" ]]
}

@test "ghs edit completes within reasonable time" {
    echo "perfuser" >> "$GH_USERS_CONFIG"
    echo "perfuser	Test	test@example.com		github.com" >> "$GH_USER_PROFILES"
    
    local duration=$(measure_time_ms ghs edit perfuser --name "New Name")
    echo "# Duration: ${duration}ms" >&3
    # Allow up to 350ms for bash script startup overhead and file operations in CI
    local timeout=$(get_timeout_ms 350)
    [[ "$duration" -lt "$timeout" ]]
}

# Tests for refactored functions

@test "find_ssh_key_alternatives finds keys for user" {
    # Setup SSH directory with various keys
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/id_ed25519"      # Generic key
    touch "$TEST_HOME/.ssh/alice_key"       # Username match
    touch "$TEST_HOME/.ssh/id_rsa_alice"    # Username suffix
    touch "$TEST_HOME/.ssh/alice_key.pub"   # Should be excluded (public key)
    touch "$TEST_HOME/.ssh/id_rsa"          # Another generic key
    chmod 600 "$TEST_HOME/.ssh"/*
    
    # Function is already available from setup_test_environment
    run find_ssh_key_alternatives "alice"
    assert_success
    assert_output_contains "$TEST_HOME/.ssh/alice_key"
    assert_output_contains "$TEST_HOME/.ssh/id_rsa_alice"
    # Should NOT contain public keys
    assert_output_not_contains ".pub"
}

@test "profile_has_issues detects SSH key problems" {
    echo "alice" >> "$GH_USERS_CONFIG"
    echo "alice	Alice	alice@example.com	/missing/key	github.com" >> "$GH_USER_PROFILES"
    
    # Source the main script
    # Function is already available from setup_test_environment
    
    run profile_has_issues "alice"
    assert_success  # Returns 0 when issues found
}

@test "profile_has_issues detects email typos" {
    echo "bob" >> "$GH_USERS_CONFIG"
    echo "bob	Bob	bob@github.com		github.com" >> "$GH_USER_PROFILES"
    
    # Function is already available from setup_test_environment
    
    run profile_has_issues "bob"
    assert_success  # Returns 0 when issues found
}

@test "profile_has_issues returns 1 for clean profile" {
    echo "clean" >> "$GH_USERS_CONFIG"
    echo "clean	Clean User	clean@example.com		github.com" >> "$GH_USER_PROFILES"
    
    # Function is already available from setup_test_environment
    
    run profile_has_issues "clean"
    assert_failure  # Returns 1 when no issues
}

@test "cmd_edit_usage shows complete help" {
    # Function is already available from setup_test_environment
    
    run cmd_edit_usage
    assert_success
    assert_output_contains "Usage: ghs edit <username> [options]"
    assert_output_contains "--email <email>"
    assert_output_contains "--name <name>"
    assert_output_contains "--ssh-key <path>"
    assert_output_contains "Examples:"
    assert_output_contains "ghs edit alice --email"
}

@test "profile_get_field extracts fields correctly" {
    local test_profile="name:Test User
email:test@example.com
ssh_key:/path/to/key"
    
    # Function is already available from setup_test_environment
    
    run profile_get_field "$test_profile" "name"
    assert_success
    [[ "$output" == "Test User" ]]
    
    run profile_get_field "$test_profile" "email"
    assert_success
    [[ "$output" == "test@example.com" ]]
    
    run profile_get_field "$test_profile" "ssh_key"
    assert_success
    [[ "$output" == "/path/to/key" ]]
}