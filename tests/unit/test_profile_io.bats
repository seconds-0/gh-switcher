#!/usr/bin/env bats

# Test profile I/O functionality with v5 tab-delimited format

load '../helpers/test_helper'
load '../helpers/ssh_helper'

setup() {
    setup_test_environment
    setup_test_ssh_environment
}

teardown() {
    cleanup_test_ssh_environment
    cleanup_test_environment
}

@test "write_profile_entry creates valid v5 profile format" {
    # Given
    local username="testuser"
    local name="Test User"
    local email="test@example.com"
    local ssh_key=""
    
    # When
    write_profile_entry "$username" "$name" "$email" "$ssh_key"
    
    # Then
    assert_file_exists "$GH_USER_PROFILES"
    local profile_line=$(cat "$GH_USER_PROFILES")
    
    # v5 format: username	v5	name	email	ssh_key	host
    [ "$profile_line" = "testuser	v5	Test User	test@example.com		github.com" ]
}

@test "write_profile_entry creates valid v5 profile with SSH key" {
    # Given
    local username="testuser"
    local name="Test User"
    local email="test@example.com"
    local ssh_key="/home/test/.ssh/id_rsa"
    
    # When
    write_profile_entry "$username" "$name" "$email" "$ssh_key"
    
    # Then
    assert_file_exists "$GH_USER_PROFILES"
    local profile_line=$(cat "$GH_USER_PROFILES")
    
    # v5 format: username	v5	name	email	ssh_key	host
    [ "$profile_line" = "testuser	v5	Test User	test@example.com	/home/test/.ssh/id_rsa	github.com" ]
}

@test "profile_create stores user data correctly" {
    # When
    run profile_create "testuser" "Test User" "test@example.com" "/path/to/key"
    
    # Then
    assert_success
    assert_file_exists "$GH_USER_PROFILES"
    
    local profile_line=$(cat "$GH_USER_PROFILES")
    [ "$profile_line" = "testuser	v5	Test User	test@example.com	/path/to/key	github.com" ]
}

@test "profile_get retrieves v5 format correctly" {
    # Given
    echo "testuser	v5	Test User	test@example.com	/path/to/key	github.com" > "$GH_USER_PROFILES"
    
    # When
    run profile_get "testuser"
    
    # Then
    assert_success
    assert_output_contains "name:Test User"
    assert_output_contains "email:test@example.com"
    assert_output_contains "ssh_key:/path/to/key"
    assert_output_contains "host:github.com"
}

@test "profile_get handles missing SSH key" {
    # Given
    echo "testuser	v5	Test User	test@example.com		github.com" > "$GH_USER_PROFILES"
    
    # When
    run profile_get "testuser"
    
    # Then
    assert_success
    assert_output_contains "name:Test User"
    assert_output_contains "email:test@example.com"
    assert_output_contains "ssh_key:"
}

@test "profile_get handles missing profile gracefully" {
    # When
    run profile_get "nonexistent"
    
    # Then
    assert_failure
}

@test "profile_get only supports v5 format" {
    # Given - v4 format (no longer supported)
    echo "testuser|v4|Test User|test@example.com|/path/to/key|github.com" > "$GH_USER_PROFILES"
    
    # When
    run profile_get "testuser"
    
    # Then - should fail as v4 is not supported
    assert_failure
    assert_output_contains "Found v4 format profile - migration needed"
}

@test "multiple profiles can coexist" {
    # Given
    profile_create "user1" "User One" "user1@example.com" "/path/to/key1" >/dev/null 2>&1
    profile_create "user2" "User Two" "user2@example.com" "/path/to/key2" >/dev/null 2>&1
    
    # When/Then - user1
    run profile_get "user1"
    assert_success
    assert_output_contains "name:User One"
    
    # When/Then - user2
    run profile_get "user2"
    assert_success
    assert_output_contains "name:User Two"
}

@test "profile_create replaces existing profile" {
    # Given
    profile_create "testuser" "Old Name" "old@example.com" "/old/key" >/dev/null 2>&1
    
    # When
    run profile_create "testuser" "New Name" "new@example.com" "/new/key"
    
    # Then
    assert_success
    
    # Verify only one profile exists
    local line_count=$(wc -l < "$GH_USER_PROFILES")
    [ "$line_count" -eq 1 ]
    
    # Verify it's the new one
    run profile_get "testuser"
    assert_output_contains "name:New Name"
}

@test "profile_remove deletes user profile" {
    # Given
    profile_create "testuser" "Test User" "test@example.com" "" >/dev/null 2>&1
    profile_create "keepuser" "Keep User" "keep@example.com" "" >/dev/null 2>&1
    
    # When
    run profile_remove "testuser"
    
    # Then
    assert_success
    
    # Verify testuser is gone
    run profile_get "testuser"
    assert_failure
    
    # Verify keepuser remains
    run profile_get "keepuser"
    assert_success
}