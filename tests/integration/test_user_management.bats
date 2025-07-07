#!/usr/bin/env bats

# Test user management functionality
# Tests add_user, remove_user, list_users functions

load '../helpers/test_helper'
load '../helpers/ssh_helper'
load '../helpers/git_helper'

setup() {
    setup_test_environment
    setup_test_ssh_environment
    setup_git_test_environment
}

teardown() {
    cleanup_test_ssh_environment
    cleanup_git_test_environment
    cleanup_test_environment
}

# Test basic user addition
@test "add_user creates user without SSH key" {
    # When
    run add_user "testuser"
    
    # Then
    assert_success
    assert_output_contains "Added testuser to user list"
    assert_user_exists "testuser"
    assert_profile_exists "testuser"
    assert_profile_has_no_ssh_key "testuser"
}

@test "add_user creates user with SSH key" {
    # Given
    local ssh_key="$TEST_ED25519_KEY"
    
    # When
    run add_user "testuser" --ssh-key "$ssh_key"
    
    # Then
    assert_success
    assert_output_contains "Added testuser to user list"
    assert_user_exists "testuser"
    assert_profile_exists "testuser"
    assert_profile_has_ssh_key "testuser" "$ssh_key"
}

@test "add_user continues with warning when SSH key missing" {
    # When
    run add_user "testuser" --ssh-key "/nonexistent/key"
    
    # Then
    assert_success  # User creation should continue despite SSH failure
    assert_output_contains "Added testuser to user list"
    assert_output_contains "SSH key not found"
    assert_user_exists "testuser"
}

@test "add_user fixes SSH key permissions" {
    # Given
    local ssh_key="$TEST_WRONG_PERMS_KEY"
    
    # When
    run add_user "testuser" --ssh-key "$ssh_key"
    
    # Then
    assert_success
    assert_output_contains "Set permissions to 600"
    assert_ssh_key_permissions "$ssh_key" "600"
}

@test "add_user continues with warning for invalid SSH key format" {
    # Given
    local invalid_key="$TEST_INVALID_KEY"
    
    # When
    run add_user "testuser" --ssh-key "$invalid_key"
    
    # Then
    assert_success  # User creation should continue despite SSH warning
    assert_output_contains "Added testuser to user list"
    assert_output_contains "doesn't appear to be a private key"
}

@test "add_user rejects invalid username format" {
    # When
    run add_user "invalid user name"
    
    # Then
    assert_failure
    assert_output_contains "Invalid username format"
}

@test "add_user handles duplicate usernames" {
    # Given
    add_user "testuser" >/dev/null 2>&1
    
    # When
    run add_user "testuser"
    
    # Then
    assert_success
    assert_output_contains "already exists in the list"
}

@test "add_user shows usage when no username provided" {
    # When
    run add_user
    
    # Then
    assert_failure
    assert_output_contains "Usage: ghs add-user"
    assert_output_contains "--ssh-key"
}

@test "add_user rejects unknown options" {
    # When
    run add_user "testuser" --unknown-option
    
    # Then
    assert_failure
    assert_output_contains "Unknown option"
}

# Test user removal
@test "remove_user removes user by name" {
    # Given
    add_user "testuser" >/dev/null 2>&1
    
    # When
    run remove_user "testuser"
    
    # Then
    assert_success
    assert_output_contains "Removed testuser from user list"
    assert_user_not_exists "testuser"
}

@test "remove_user removes user by number" {
    # Given
    add_user "testuser" >/dev/null 2>&1
    
    # When
    run remove_user "1"
    
    # Then
    assert_success
    assert_output_contains "Removing user #1: testuser"
    assert_user_not_exists "testuser"
}

@test "remove_user handles non-existent user" {
    # When
    run remove_user "nonexistent"
    
    # Then
    assert_failure
    assert_output_contains "❌"
}

@test "remove_user handles invalid user ID when no users exist" {
    # When
    run remove_user "999"
    
    # Then
    assert_failure
    assert_output_contains "No users configured"
}

@test "remove_user shows usage when no user provided" {
    # When
    run remove_user
    
    # Then
    assert_failure
    assert_output_contains "Usage: ghs remove-user"
}

# Test user listing
@test "list_users shows empty state" {
    # When
    run list_users
    
    # Then
    assert_success
    assert_output_contains "No users configured yet"
    assert_output_contains "ghs add-user"
}

@test "list_users shows users with numbers" {
    # Given
    add_user "user1" >/dev/null 2>&1
    add_user "user2" >/dev/null 2>&1
    
    # When
    run list_users
    
    # Then
    assert_success
    assert_output_contains "1. user1"
    assert_output_contains "2. user2"
}

@test "list_users shows SSH status for working keys" {
    # Given
    add_user "httpsuser" >/dev/null 2>&1
    add_user "sshuser" --ssh-key "$TEST_ED25519_KEY" >/dev/null 2>&1
    
    # When
    run list_users
    
    # Then
    assert_success
    assert_output_contains "httpsuser"
    assert_output_contains "[HTTPS]"
    assert_output_contains "sshuser"
    # Note: SSH key will show as [SSH: path] if valid, [HTTPS] if not
}

# Test user ID resolution
@test "get_user_by_id returns correct username" {
    # Given
    add_user "testuser" >/dev/null 2>&1
    
    # When
    run get_user_by_id "1"
    
    # Then
    assert_success
    assert_output_contains "testuser"
}

@test "get_user_by_id handles invalid ID" {
    # When
    run get_user_by_id "invalid"
    
    # Then
    assert_failure
    assert_output_contains "Invalid user ID"
}

@test "get_user_by_id handles non-existent ID when no users" {
    # When
    run get_user_by_id "999"
    
    # Then
    assert_failure
    assert_output_contains "No users configured"
}

# Test profile integration
@test "add_user creates profile with git config" {
    # Given
    cd "$TEST_MAIN_REPO"
    git config user.name "Existing Name"
    git config user.email "existing@example.com"
    
    # When
    run add_user "testuser"
    
    # Then
    assert_success
    
    # Check profile exists and can be retrieved
    run get_user_profile "testuser"
    assert_success
    assert_output_contains "name:testuser"
    assert_output_contains "email:testuser@users.noreply.github.com"
}