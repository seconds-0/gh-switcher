#!/usr/bin/env bats

# Test profile I/O functionality
# Tests encoding/decoding and round-trip integrity

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

# Test basic profile encoding/decoding
@test "encode_profile_value handles simple strings" {
    # When
    run encode_profile_value "test"
    
    # Then
    assert_success
    [[ -n "$output" ]]
    
    # Round-trip test
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [[ "$output" == "test" ]]
}

@test "encode_profile_value handles strings with spaces" {
    # When
    run encode_profile_value "Test User Name"
    
    # Then
    assert_success
    [[ -n "$output" ]]
    
    # Round-trip test
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [[ "$output" == "Test User Name" ]]
}

@test "encode_profile_value handles email addresses" {
    # When
    run encode_profile_value "test.user+tag@example.com"
    
    # Then
    assert_success
    [[ -n "$output" ]]
    
    # Round-trip test
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [[ "$output" == "test.user+tag@example.com" ]]
}

@test "encode_profile_value handles special characters" {
    # When
    run encode_profile_value "User: Name & Co."
    
    # Then
    assert_success
    [[ -n "$output" ]]
    
    # Round-trip test
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [[ "$output" == "User: Name & Co." ]]
}

@test "encode_profile_value produces no colons in output" {
    # When
    run encode_profile_value "test:with:colons"
    
    # Then
    assert_success
    # Encoded value should not contain colons (which would break profile format)
    [[ "$output" != *":"* ]]
    
    # Round-trip test
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [[ "$output" == "test:with:colons" ]]
}

@test "write_profile_entry creates valid profile format" {
    # When
    run write_profile_entry "testuser" "Test User" "test@example.com" ""
    
    # Then
    assert_success
    assert_file_exists "$GH_USER_PROFILES"
    
    # Check profile format
    local profile_line=$(cat "$GH_USER_PROFILES")
    local field_count=$(echo "$profile_line" | tr ':' '\n' | wc -l)
    [[ "$field_count" -eq 5 ]]
    
    # Check username is correct
    [[ "$profile_line" == testuser:* ]]
    
    # Check version is 2
    local version=$(echo "$profile_line" | cut -d':' -f2)
    [[ "$version" == "2" ]]
}

@test "write_profile_entry creates valid profile with SSH key" {
    # When
    run write_profile_entry "testuser" "Test User" "test@example.com" "$TEST_ED25519_KEY"
    
    # Then
    assert_success
    assert_file_exists "$GH_USER_PROFILES"
    
    # Check profile format
    local profile_line=$(cat "$GH_USER_PROFILES")
    local field_count=$(echo "$profile_line" | tr ':' '\n' | wc -l)
    [[ "$field_count" -eq 5 ]]
    
    # Check that SSH key field is not empty
    local ssh_field=$(echo "$profile_line" | cut -d':' -f5)
    [[ -n "$ssh_field" ]]
}

@test "profile round-trip preserves all data" {
    # Given
    local username="testuser"
    local name="Test User Name"
    local email="test.user+tag@example.com"
    local ssh_key="$TEST_ED25519_KEY"
    
    # When - write profile
    run write_profile_entry "$username" "$name" "$email" "$ssh_key"
    assert_success
    
    # Then - read profile back
    run get_user_profile "$username"
    assert_success
    
    # Verify all fields are preserved
    local profile="$output"
    local retrieved_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local retrieved_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local retrieved_ssh=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    [[ "$retrieved_name" == "$name" ]]
    [[ "$retrieved_email" == "$email" ]]
    [[ "$retrieved_ssh" == "$ssh_key" ]]
}

@test "profile round-trip works without SSH key" {
    # Given
    local username="testuser"
    local name="Test User Name"
    local email="test.user+tag@example.com"
    
    # When - write profile without SSH key
    run write_profile_entry "$username" "$name" "$email" ""
    assert_success
    
    # Then - read profile back
    run get_user_profile "$username"
    assert_success
    
    # Verify all fields are preserved and SSH key is empty
    local profile="$output"
    local retrieved_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local retrieved_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local retrieved_ssh=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    [[ "$retrieved_name" == "$name" ]]
    [[ "$retrieved_email" == "$email" ]]
    [[ -z "$retrieved_ssh" ]]
}

@test "get_user_profile handles missing profile gracefully" {
    # When
    run get_user_profile "nonexistent"
    
    # Then
    assert_failure
}

@test "multiple profiles can coexist" {
    # Test step 1: create profiles
    write_profile_entry "user1" "User One" "user1@example.com" "$TEST_ED25519_KEY" >/dev/null 2>&1
    write_profile_entry "user2" "User Two" "user2@example.com" "" >/dev/null 2>&1
    
    # Test step 2: test first profile with assertions
    run get_user_profile "user1"
    assert_success
    assert_output_contains "User One"
    assert_output_contains "ssh_key:$TEST_ED25519_KEY"
    
    # Test step 3: test second profile 
    run get_user_profile "user2"
    assert_success
    assert_output_contains "User Two"
    [[ "$output" != *"ssh_key:"* ]]
    echo "All tests completed successfully"
}