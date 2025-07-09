#!/usr/bin/env bats

# Integration tests for SSH key workflows in add_user

setup() {
    load "../helpers/test_helper"
    load "../helpers/ssh_helper"
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "add_user with single SSH key detected and used automatically" {
    # Create a single SSH key for work-account
    create_fake_ssh_key "id_ed25519_work-account"
    
    run add_user "work-account"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"🔍 Found SSH key:"* ]]
    [[ "$output" == *"id_ed25519_work-account"* ]]
    [[ "$output" == *"✅ Added work-account to user list"* ]]
    
    # Check that user was added to config
    grep -q "^work-account$" "$GH_USERS_CONFIG"
}

@test "add_user with multiple SSH keys shows copy-paste commands" {
    # Create multiple SSH keys for work-account
    create_fake_ssh_key "id_ed25519_work-account"
    create_fake_ssh_key "id_rsa_work-account"
    
    run add_user "work-account"
    
    [ "$status" -eq 1 ]  # Should fail and ask user to specify
    [[ "$output" == *"🔍 Found multiple SSH keys:"* ]]
    [[ "$output" == *"id_ed25519_work-account"* ]]
    [[ "$output" == *"id_rsa_work-account"* ]]
    [[ "$output" == *"Specify which one to use:"* ]]
    [[ "$output" == *"ghs add-user work-account --ssh-key"* ]]
    
    # User should NOT be added to config when multiple keys found
    ! grep -q "^work-account$" "$GH_USERS_CONFIG"
}

@test "add_user with no SSH keys found defaults to HTTPS" {
    # Don't create any SSH keys
    
    run add_user "work-account"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"📝 No SSH keys found, using HTTPS"* ]]
    [[ "$output" == *"✅ Added work-account to user list"* ]]
    
    # Check that user was added to config
    grep -q "^work-account$" "$GH_USERS_CONFIG"
}

@test "add_user with manual --ssh-key override works" {
    # Create SSH key with custom name
    local key_path
    key_path=$(create_fake_ssh_key "custom_work_key")
    
    run add_user "work-account" --ssh-key "$key_path"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ Added work-account to user list"* ]]
    
    # Check that user was added
    grep -q "^work-account$" "$GH_USERS_CONFIG"
}

@test "add_user with --no-ssh flag skips detection" {
    # Create SSH keys that would normally be detected
    create_fake_ssh_key "id_ed25519_work-account"
    
    run add_user "work-account" --no-ssh
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"📝 Using HTTPS mode (--no-ssh specified)"* ]]
    [[ "$output" == *"✅ Added work-account to user list"* ]]
    
    # Should not mention SSH key detection
    [[ "$output" != *"🔍 Found SSH key"* ]]
}

@test "add_user fixes SSH key permissions automatically" {
    # Create SSH key with wrong permissions
    local key_path
    key_path=$(create_fake_ssh_key "id_ed25519_work-account" "644")
    
    run add_user "work-account"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"🔧 Fixed SSH key permissions (644 → 600)"* ]]
    [[ "$output" == *"🔍 Found SSH key:"* ]]
    [[ "$output" == *"✅ Added work-account to user list"* ]]
    
    # Check that permissions were actually fixed
    assert_key_permissions_fixed "$key_path" "600"
}

@test "add_user handles missing SSH key file gracefully" {
    # Manually specify a non-existent SSH key
    run add_user "work-account" --ssh-key "/nonexistent/key"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"❌ SSH key not found: /nonexistent/key"* ]]
    
    # User should not be added when SSH key validation fails
    ! grep -q "^work-account$" "$GH_USERS_CONFIG"
}

@test "add_user rejects duplicate usernames" {
    # Add user once
    echo "work-account" >> "$GH_USERS_CONFIG"
    
    run add_user "work-account"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠️  User work-account already exists in the list"* ]]
    
    # Should have exactly one entry
    [ "$(grep -c "^work-account$" "$GH_USERS_CONFIG")" -eq 1 ]
}

@test "add_user validates username format" {
    # Try to add user with invalid characters
    run add_user "invalid@username"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"❌ Invalid username format"* ]]
    
    # User should not be added
    ! grep -q "^invalid@username$" "$GH_USERS_CONFIG"
}

@test "add_user handles current keyword" {
    # Use standardized mock helper
    create_mock_gh "github-user" "true"
    
    run add_user "current"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"💡 Adding current GitHub user: github-user"* ]]
    [[ "$output" == *"✅ Added github-user to user list"* ]]
    
    # Check that actual GitHub user was added
    grep -q "^github-user$" "$GH_USERS_CONFIG"
    
    # Clean up
    remove_mock_gh
}

@test "add_user shows usage when no username provided" {
    run add_user
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"❌ Usage: ghs add-user <username> [--ssh-key <path>] [--no-ssh]"* ]]
    [[ "$output" == *"Examples:"* ]]
    [[ "$output" == *"ghs add-user work-account --ssh-key"* ]]
    [[ "$output" == *"ghs add-user current --no-ssh"* ]]
}

@test "add_user shows error for unknown options" {
    run add_user "work-account" --unknown-option
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"❌ Unknown option: --unknown-option"* ]]
    [[ "$output" == *"Usage: ghs add-user <username> [--ssh-key ~/.ssh/id_rsa] [--no-ssh]"* ]]
}