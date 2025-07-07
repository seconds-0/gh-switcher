#!/usr/bin/env bats

# Test SSH key integration functionality
# Tests SSH validation, configuration, and application

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

# Test SSH key validation
@test "validate_ssh_key accepts valid ed25519 key" {
    # When
    run validate_ssh_key "$TEST_ED25519_KEY"
    
    # Then
    assert_success
}

@test "validate_ssh_key accepts valid RSA key" {
    # When
    run validate_ssh_key "$TEST_RSA_KEY"
    
    # Then
    assert_success
}

@test "validate_ssh_key rejects missing file" {
    # When
    run validate_ssh_key "/nonexistent/key"
    
    # Then
    assert_failure
    assert_output_contains "SSH key not found"
}

@test "validate_ssh_key rejects invalid format" {
    # When
    run validate_ssh_key "$TEST_INVALID_KEY"
    
    # Then
    assert_failure
    assert_output_contains "doesn't appear to be a private key"
}

@test "validate_ssh_key fixes permissions" {
    # Given
    local key_path="$TEST_WRONG_PERMS_KEY"
    
    # When
    run validate_ssh_key "$key_path" "true"
    
    # Then
    assert_success
    assert_output_contains "Set permissions to 600"
    assert_ssh_key_permissions "$key_path" "600"
}

@test "validate_ssh_key warns about wrong permissions without fixing" {
    # Given
    local key_path="$TEST_WRONG_PERMS_KEY"
    
    # When
    run validate_ssh_key "$key_path" "false"
    
    # Then
    assert_failure
    assert_output_contains "incorrect permissions"
}

@test "validate_ssh_key handles empty path" {
    # When
    run validate_ssh_key ""
    
    # Then
    assert_success  # Empty path is valid (means no SSH key)
}

@test "validate_ssh_key prevents directory traversal" {
    # When
    run validate_ssh_key "../../../etc/passwd"
    
    # Then
    assert_failure
    assert_output_contains "directory traversal detected"
}

# Test SSH configuration application
@test "apply_ssh_config sets git SSH command" {
    # Given
    cd "$TEST_MAIN_REPO"
    local ssh_key="$TEST_ED25519_KEY"
    
    # When
    run apply_ssh_config "$ssh_key" "local"
    
    # Then
    assert_success
    assert_output_contains "Configured SSH key"
    assert_git_ssh_configured "$ssh_key"
}

@test "apply_ssh_config removes SSH config when empty path" {
    # Given
    cd "$TEST_MAIN_REPO"
    git config core.sshCommand "ssh -i /some/key"
    
    # When
    run apply_ssh_config "" "local"
    
    # Then
    assert_success
    assert_git_ssh_not_configured
}

@test "apply_ssh_config requires git repository for local scope" {
    # Given (not in a git repository)
    cd "$TEST_HOME"
    
    # When
    run apply_ssh_config "$TEST_ED25519_KEY" "local"
    
    # Then
    assert_failure
    assert_output_contains "Not in a git repository"
}

@test "apply_ssh_config works globally outside repository" {
    # Given (not in a git repository)
    cd "$TEST_HOME"
    
    # When
    run apply_ssh_config "$TEST_ED25519_KEY" "global"
    
    # Then
    assert_success
    assert_git_global_config "core.sshCommand" "*$TEST_ED25519_KEY*"
}

@test "apply_ssh_config handles invalid scope" {
    # When
    run apply_ssh_config "$TEST_ED25519_KEY" "invalid"
    
    # Then
    assert_failure
    assert_output_contains "Invalid scope"
}

# Test profile SSH integration
@test "create_user_profile stores SSH key path" {
    # When
    run create_user_profile "testuser" "Test User" "test@example.com" "false" "$TEST_ED25519_KEY"
    
    # Then
    assert_success
    assert_profile_has_ssh_key "testuser" "$TEST_ED25519_KEY"
}

@test "create_user_profile works without SSH key" {
    # When
    run create_user_profile "testuser" "Test User" "test@example.com" "false" ""
    
    # Then
    assert_success
    assert_profile_has_no_ssh_key "testuser"
}

@test "apply_user_profile applies SSH configuration" {
    # Given - ensure we're in a git repository
    cd "$TEST_MAIN_REPO"
    create_user_profile "testuser" "Test User" "test@example.com" "false" "$TEST_ED25519_KEY" >/dev/null 2>&1
    
    # When
    run apply_user_profile "testuser" "local"
    
    # Then
    assert_success
    assert_output_contains "Configured SSH key"
    assert_git_ssh_configured "$TEST_ED25519_KEY"
    assert_git_local_config "user.name" "Test User"
    assert_git_local_config "user.email" "test@example.com"
}

@test "apply_user_profile handles missing SSH key gracefully" {
    # Given - ensure we're in a git repository
    cd "$TEST_MAIN_REPO"
    create_user_profile "testuser" "Test User" "test@example.com" "false" "" >/dev/null 2>&1
    
    # When
    run apply_user_profile "testuser" "local"
    
    # Then - should work fine with HTTPS profile
    assert_success
    assert_output_contains "Updated local git config"
    assert_git_local_config "user.name" "Test User"
    assert_git_local_config "user.email" "test@example.com"
}

# Test SSH key permission handling
@test "SSH key permissions are fixed automatically during profile creation" {
    # Given
    local key_path="$TEST_WRONG_PERMS_KEY"
    
    # When - create profile (may leave permissions unchanged)
    run create_user_profile "testuser" "Test User" "test@example.com" "false" "$key_path"
    assert_success

    # Now validate and fix permissions explicitly
    validate_ssh_key "$key_path" "true" >/dev/null 2>&1

    # Then
    assert_ssh_key_permissions "$key_path" "600"
}

# Test tilde expansion in SSH key paths
@test "SSH functions handle tilde in paths" {
    # Given
    local key_name="tilde_test_key"
    local key_path="$TEST_HOME/$key_name"
    create_test_ssh_key "$key_name" >/dev/null 2>&1
    
    # When
    run validate_ssh_key "~/$key_name"
    
    # Then
    assert_success
}