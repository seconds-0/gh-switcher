#!/usr/bin/env bats

# Unit tests for SSH key detection and permission fixing

setup() {
    load "../helpers/test_helper"
    load "../helpers/ssh_helper"
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "detect_ssh_keys finds username-specific keys" {
    # Create SSH keys matching username patterns
    create_fake_ssh_key "id_ed25519_work"
    create_fake_ssh_key "id_rsa_work"
    
    run detect_ssh_keys "work"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"id_ed25519_work"* ]]
    [[ "$output" == *"id_rsa_work"* ]]
}

@test "detect_ssh_keys finds default keys when no username match" {
    # Create only default keys
    create_fake_ssh_key "id_ed25519"
    create_fake_ssh_key "id_rsa"
    
    run detect_ssh_keys "nonexistent"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"id_ed25519"* ]]
    [[ "$output" == *"id_rsa"* ]]
}

@test "detect_ssh_keys returns empty when no keys found" {
    # Don't create any keys
    
    run detect_ssh_keys "work"
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "detect_ssh_keys finds github pattern keys" {
    # Create github-pattern keys
    create_fake_ssh_key "id_ed25519_github"
    create_fake_ssh_key "id_rsa_github"
    
    run detect_ssh_keys "work"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"id_ed25519_github"* ]]
    [[ "$output" == *"id_rsa_github"* ]]
}

@test "fix_ssh_permissions fixes 644 to 600" {
    # Create key with wrong permissions
    local key_path
    key_path=$(create_fake_ssh_key "test_key" "644")
    
    run fix_ssh_permissions "$key_path"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fixed SSH key permissions (644 → 600)"* ]]
    assert_key_permissions_fixed "$key_path" "600"
}

@test "fix_ssh_permissions skips correct permissions" {
    # Create key with correct permissions
    local key_path
    key_path=$(create_fake_ssh_key "test_key" "600")
    
    run fix_ssh_permissions "$key_path"
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]  # No output when no fix needed
    assert_key_permissions_fixed "$key_path" "600"
}

@test "fix_ssh_permissions skips symlinks" {
    # Create a regular file and symlink to it
    local target_path
    target_path=$(create_fake_ssh_key "target_key" "644")
    local symlink_path="$TEST_HOME/.ssh/symlink_key"
    ln -s "$target_path" "$symlink_path"
    
    run fix_ssh_permissions "$symlink_path"
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]  # No output when skipping symlink
    
    # Target should still have wrong permissions
    local actual_perms
    actual_perms=$(stat -c %a "$target_path" 2>/dev/null || stat -f %Lp "$target_path" 2>/dev/null)
    [ "$actual_perms" = "644" ]
}

@test "fix_ssh_permissions handles permission fix failure gracefully" {
    # Create key with wrong permissions in a read-only directory
    local key_path
    key_path=$(create_fake_ssh_key "test_key" "644")
    
    # Make the parent directory read-only to simulate permission fix failure
    chmod 444 "$(dirname "$key_path")"
    
    run fix_ssh_permissions "$key_path"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠️  Could not fix SSH key permissions"* ]]
    
    # Restore directory permissions for cleanup
    chmod 755 "$(dirname "$key_path")"
}

@test "validate_ssh_key accepts empty path" {
    run validate_ssh_key ""
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "validate_ssh_key accepts valid key file" {
    local key_path
    key_path=$(create_fake_ssh_key "valid_key")
    
    run validate_ssh_key "$key_path"
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "validate_ssh_key rejects missing key file" {
    run validate_ssh_key "/nonexistent/path"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"SSH key not found"* ]]
}

@test "validate_ssh_key expands tilde in path" {
    # Create key in home directory
    local key_path
    key_path=$(create_fake_ssh_key "home_key")
    local relative_path="~/.ssh/home_key"
    
    run validate_ssh_key "$relative_path"
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "detect_ssh_keys excludes public key files" {
    # Create both private and public keys
    mkdir -p "$TEST_HOME/.ssh"
    echo "private key" > "$TEST_HOME/.ssh/id_ed25519_test"
    echo "public key" > "$TEST_HOME/.ssh/id_ed25519_test.pub"
    echo "private key" > "$TEST_HOME/.ssh/id_rsa_test"
    echo "public key" > "$TEST_HOME/.ssh/id_rsa_test.pub"
    
    run detect_ssh_keys "test"
    
    [ "$status" -eq 0 ]
    # Should find both private keys
    [[ "$output" == *"id_ed25519_test"* ]]
    [[ "$output" == *"id_rsa_test"* ]]
    # Should NOT find public keys
    [[ "$output" != *".pub"* ]]
}