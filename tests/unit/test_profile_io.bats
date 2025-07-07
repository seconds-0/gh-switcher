#!/usr/bin/env bats

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

@test "encode_profile_value handles simple strings" {
    run encode_profile_value "test"
    assert_success
    [ -n "$output" ]
    
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [ "$output" = "test" ]
}

@test "encode_profile_value handles strings with spaces" {
    run encode_profile_value "Test User Name"
    assert_success
    [ -n "$output" ]
    
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [ "$output" = "Test User Name" ]
}

@test "encode_profile_value handles email addresses" {
    run encode_profile_value "test.user+tag@example.com"
    assert_success
    [ -n "$output" ]
    
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [ "$output" = "test.user+tag@example.com" ]
}

@test "encode_profile_value handles special characters" {
    run encode_profile_value "User: Name & Co."
    assert_success
    [ -n "$output" ]
    
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [ "$output" = "User: Name & Co." ]
}

@test "encode_profile_value produces no colons in output" {
    run encode_profile_value "test:with:colons"
    assert_success
    case "$output" in *:*) false;; *) true;; esac
    
    local encoded="$output"
    run decode_profile_value "$encoded"
    assert_success
    [ "$output" = "test:with:colons" ]
}

@test "write_profile_entry creates valid profile format" {
    run write_profile_entry "testuser" "Test User" "test@example.com" ""
    assert_success
    assert_file_exists "$GH_USER_PROFILES"
    
    local profile_line=$(cat "$GH_USER_PROFILES")
    local field_count=$(echo "$profile_line" | tr ':' '\n' | wc -l)
    [ "$field_count" -eq 5 ]
    
    case "$profile_line" in testuser:*) true;; *) false;; esac
    
    local version=$(echo "$profile_line" | cut -d':' -f2)
    [ "$version" = "2" ]
}

@test "write_profile_entry creates valid profile with SSH key" {
    run write_profile_entry "testuser" "Test User" "test@example.com" "$TEST_ED25519_KEY"
    assert_success
    assert_file_exists "$GH_USER_PROFILES"
    
    local profile_line=$(cat "$GH_USER_PROFILES")
    local field_count=$(echo "$profile_line" | tr ':' '\n' | wc -l)
    [ "$field_count" -eq 5 ]
    
    local ssh_field=$(echo "$profile_line" | cut -d':' -f5)
    [ -n "$ssh_field" ]
}

@test "profile round-trip preserves all data" {
    local username="testuser"
    local name="Test User Name"
    local email="test.user+tag@example.com"
    local ssh_key="$TEST_ED25519_KEY"
    
    run write_profile_entry "$username" "$name" "$email" "$ssh_key"
    assert_success
    
    run get_user_profile "$username"
    assert_success
    
    local profile="$output"
    local retrieved_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local retrieved_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local retrieved_ssh=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    [ "$retrieved_name" = "$name" ]
    [ "$retrieved_email" = "$email" ]
    [ "$retrieved_ssh" = "$ssh_key" ]
}

@test "profile round-trip works without SSH key" {
    local username="testuser"
    local name="Test User Name"
    local email="test.user+tag@example.com"
    
    run write_profile_entry "$username" "$name" "$email" ""
    assert_success
    
    run get_user_profile "$username"
    assert_success
    
    local profile="$output"
    local retrieved_name=$(echo "$profile" | grep "^name:" | cut -d':' -f2-)
    local retrieved_email=$(echo "$profile" | grep "^email:" | cut -d':' -f2-)
    local retrieved_ssh=$(echo "$profile" | grep "^ssh_key:" | cut -d':' -f2-)
    
    [ "$retrieved_name" = "$name" ]
    [ "$retrieved_email" = "$email" ]
    [ -z "$retrieved_ssh" ]
}

@test "get_user_profile handles missing profile gracefully" {
    run get_user_profile "nonexistent"
    assert_failure
}

@test "multiple profiles can coexist" {
    write_profile_entry "user1" "User One" "user1@example.com" "$TEST_ED25519_KEY" >/dev/null 2>&1
    write_profile_entry "user2" "User Two" "user2@example.com" "" >/dev/null 2>&1
    
    run get_user_profile "user1"
    assert_success
    assert_output_contains "User One"
    assert_output_contains "ssh_key:$TEST_ED25519_KEY"
    
    run get_user_profile "user2"
    assert_success
    assert_output_contains "User Two"
    assert_output_contains "ssh_key:"
}
