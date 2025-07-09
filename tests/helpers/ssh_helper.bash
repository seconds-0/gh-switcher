#!/usr/bin/env bash

# SSH testing helper for gh-switcher testing
# Provides SSH key creation and testing utilities

# Create a test SSH key pair
create_test_ssh_key() {
    local key_name="${1:-test_key}"
    local key_type="${2:-ed25519}"
    local key_path="$TEST_HOME/$key_name"
    
    # Create .ssh directory
    mkdir -p "$TEST_HOME/.ssh"
    
    case "$key_type" in
        "ed25519")
            ssh-keygen -t ed25519 -f "$key_path" -N "" -C "test@example.com" >/dev/null 2>&1
            ;;
        "rsa")
            ssh-keygen -t rsa -b 2048 -f "$key_path" -N "" -C "test@example.com" >/dev/null 2>&1
            ;;
        *)
            echo "Unsupported key type: $key_type" >&2
            return 1
            ;;
    esac
    
    # Ensure correct permissions
    chmod 600 "$key_path" 2>/dev/null
    chmod 644 "$key_path.pub" 2>/dev/null
    
    echo "$key_path"
}

# Create an SSH key with specific permissions (for testing permission fixes)
create_ssh_key_with_permissions() {
    local key_name="$1"
    local permissions="$2"
    local key_path
    
    key_path=$(create_test_ssh_key "$key_name")
    chmod "$permissions" "$key_path"
    echo "$key_path"
}

# Create an invalid SSH key file (not actually a key)
create_invalid_ssh_key() {
    local key_name="${1:-invalid_key}"
    local key_path="$TEST_HOME/$key_name"
    
    echo "This is not a valid SSH private key" > "$key_path"
    chmod 600 "$key_path"
    echo "$key_path"
}

# Create an SSH key that looks valid but isn't properly formatted
create_malformed_ssh_key() {
    local key_name="${1:-malformed_key}"
    local key_path="$TEST_HOME/$key_name"
    
    cat > "$key_path" << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
This looks like a key header but the content is invalid
-----END OPENSSH PRIVATE KEY-----
EOF
    
    chmod 600 "$key_path"
    echo "$key_path"
}

# Mock SSH authentication success
# Note: This doesn't actually test GitHub connectivity, just simulates success
mock_ssh_auth_success() {
    local username="${1:-testuser}"
    
    # Create a mock SSH command that returns success with expected output
    cat > "$TEST_HOME/mock_ssh" << EOF
#!/bin/bash
echo "Hi $username! You've successfully authenticated, but GitHub does not provide shell access."
exit 1  # GitHub SSH returns 1 for successful auth
EOF
    chmod +x "$TEST_HOME/mock_ssh"
    
    # Add to PATH so it gets picked up
    export PATH="$TEST_HOME:$PATH"
}

# Mock SSH authentication failure
mock_ssh_auth_failure() {
    # Create a mock SSH command that returns failure
    cat > "$TEST_HOME/mock_ssh" << 'EOF'
#!/bin/bash
echo "Permission denied (publickey)."
exit 255  # SSH connection failure
EOF
    chmod +x "$TEST_HOME/mock_ssh"
    
    # Add to PATH so it gets picked up
    export PATH="$TEST_HOME:$PATH"
}

# Restore original SSH command
restore_ssh_command() {
    # Remove mock ssh from PATH
    export PATH=$(echo "$PATH" | sed "s|$TEST_HOME:||g")
    rm -f "$TEST_HOME/mock_ssh"
}

# Assert that SSH key file has correct permissions
assert_ssh_key_permissions() {
    local key_path="$1"
    local expected_perms="${2:-600}"
    
    local actual_perms
    actual_perms=$(stat -c %a "$key_path" 2>/dev/null || stat -f %Lp "$key_path" 2>/dev/null)
    
    [[ "$actual_perms" == "$expected_perms" ]] || {
        echo "Expected SSH key permissions $expected_perms, got $actual_perms for $key_path"
        return 1
    }
}

# Assert that SSH key file looks like a valid private key
assert_ssh_key_format() {
    local key_path="$1"
    
    grep -q "BEGIN.*PRIVATE KEY" "$key_path" || {
        echo "SSH key file does not appear to be a private key: $key_path"
        return 1
    }
}

# Assert that SSH key validation passes
assert_ssh_key_valid() {
    local key_path="$1"
    
    validate_ssh_key "$key_path" "false" >/dev/null 2>&1 || {
        echo "SSH key validation failed for: $key_path"
        return 1
    }
}

# Assert that SSH key validation fails
assert_ssh_key_invalid() {
    local key_path="$1"
    
    ! validate_ssh_key "$key_path" "false" >/dev/null 2>&1 || {
        echo "Expected SSH key validation to fail for: $key_path"
        return 1
    }
}

# Set up test SSH environment with multiple keys
setup_test_ssh_environment() {
    # Create various test keys for different scenarios
    export TEST_ED25519_KEY=$(create_test_ssh_key "test_ed25519" "ed25519")
    export TEST_RSA_KEY=$(create_test_ssh_key "test_rsa" "rsa")
    export TEST_INVALID_KEY=$(create_invalid_ssh_key "test_invalid")
    export TEST_MALFORMED_KEY=$(create_malformed_ssh_key "test_malformed")
    export TEST_WRONG_PERMS_KEY=$(create_ssh_key_with_permissions "test_perms" "644")
}

# Clean up SSH test environment
cleanup_test_ssh_environment() {
    restore_ssh_command
    unset TEST_ED25519_KEY TEST_RSA_KEY TEST_INVALID_KEY TEST_MALFORMED_KEY TEST_WRONG_PERMS_KEY
}

# Create a fake SSH key with specific name and permissions (for simplified testing)
create_fake_ssh_key() {
    local key_name="$1"
    local permissions="${2:-600}"
    local key_path="$TEST_HOME/.ssh/$key_name"
    
    mkdir -p "$TEST_HOME/.ssh"
    
    # Create fake SSH key with proper header
    cat > "$key_path" << 'EOF'
-----BEGIN PRIVATE KEY-----
fake-key-content-for-testing
-----END PRIVATE KEY-----
EOF
    
    chmod "$permissions" "$key_path"
    echo "$key_path"
}

# Assert that key permissions were fixed
assert_key_permissions_fixed() {
    local key_path="$1"
    local expected_perms="${2:-600}"
    
    local actual_perms
    actual_perms=$(stat -c %a "$key_path" 2>/dev/null || stat -f %Lp "$key_path" 2>/dev/null)
    
    [[ "$actual_perms" == "$expected_perms" ]] || {
        echo "Expected key permissions $expected_perms, got $actual_perms for $key_path"
        return 1
    }
}

# Create test scenario with multiple SSH keys for detection testing
create_multi_key_scenario() {
    local username="$1"
    mkdir -p "$TEST_HOME/.ssh"
    
    # Create keys matching different patterns
    create_fake_ssh_key "id_ed25519_${username}"
    create_fake_ssh_key "id_rsa_${username}"
    create_fake_ssh_key "id_ed25519"
    create_fake_ssh_key "id_rsa"
}