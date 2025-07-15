#!/usr/bin/env bash

# E2E Test Helper Functions for gh-switcher
# Provides utilities for testing shell interactions

# Set up a clean test environment for E2E tests
setup_e2e_test_env() {
    # Create isolated test directory
    export E2E_TEST_HOME=$(mktemp -d -t "ghs-e2e-test.XXXXXX")
    export ORIGINAL_HOME="$HOME"
    export ORIGINAL_PATH="$PATH"
    
    # Set test HOME to isolate config files
    export HOME="$E2E_TEST_HOME"
    
    # Create minimal directory structure
    mkdir -p "$HOME/.config/gh-switcher"
    mkdir -p "$HOME/.ssh"
    mkdir -p "$HOME/bin"
    
    # Override config paths to use test environment
    export GH_USERS_CONFIG="$HOME/.config/gh-switcher/users"
    export GH_USER_PROFILES="$HOME/.gh-user-profiles"
    export GH_PROJECT_CONFIG="$HOME/.gh-project-accounts"
    
    # Add test bin to PATH for mocks
    export PATH="$HOME/bin:$PATH"
}

# Clean up test environment
cleanup_e2e_test_env() {
    # Restore original environment
    export HOME="$ORIGINAL_HOME"
    export PATH="$ORIGINAL_PATH"
    
    # Remove test directory
    if [[ -n "$E2E_TEST_HOME" && -d "$E2E_TEST_HOME" ]]; then
        rm -rf "$E2E_TEST_HOME"
    fi
    
    # Unset test variables
    unset E2E_TEST_HOME
    unset GH_USERS_CONFIG
    unset GH_USER_PROFILES
    unset GH_PROJECT_CONFIG
}

# Create a mock gh CLI for predictable testing
create_mock_gh() {
    cat > "$HOME/bin/gh" << 'EOF'
#!/bin/bash
# Mock gh CLI for E2E testing

case "$*" in
    "auth status")
        echo "github.com - Logged in as testuser"
        ;;
    "auth status --show-token")
        echo "Logged in to github.com as testuser (oauth_token: gho_XXXXXXXX)"
        ;;
    "api user -q .login")
        echo "${MOCK_GH_USER:-testuser}"
        ;;
    "api user")
        echo '{"login":"testuser","email":"testuser@example.com","name":"Test User"}'
        ;;
    "auth switch --user testuser1")
        export MOCK_GH_USER=testuser1
        echo "✓ Switched to testuser1"
        ;;
    "auth switch --user testuser2")
        export MOCK_GH_USER=testuser2
        echo "✓ Switched to testuser2"
        ;;
    "auth switch --user "*)
        user="${*##--user }"
        echo "Error: User '$user' not found" >&2
        exit 1
        ;;
    *)
        echo "Mock gh: Unknown command: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$HOME/bin/gh"
}

# Run a command in a specific shell and capture output
run_in_shell() {
    local shell="$1"
    shift
    local command="$*"
    
    # Use timeout to prevent hanging tests
    timeout 5 "$shell" -c "$command" 2>&1
}

# Assert that a shell command succeeds
assert_shell_command_succeeds() {
    local shell="$1"
    local command="$2"
    local output
    local status
    
    output=$(run_in_shell "$shell" "$command")
    status=$?
    
    if [[ $status -ne 0 ]]; then
        echo "Command failed in $shell with status $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
    
    echo "$output"
    return 0
}

# Check if a shell is available
shell_available() {
    local shell="$1"
    command -v "$shell" >/dev/null 2>&1
}

# Create test SSH keys
create_test_ssh_keys() {
    touch "$HOME/.ssh/testuser1_ed25519"
    touch "$HOME/.ssh/testuser2_ed25519"
    chmod 600 "$HOME/.ssh/"*_ed25519
    
    # Create fake public keys
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... testuser1@example.com" > "$HOME/.ssh/testuser1_ed25519.pub"
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... testuser2@example.com" > "$HOME/.ssh/testuser2_ed25519.pub"
    
    # Create mock SSH for testing
    cat > "$HOME/bin/ssh" << 'EOF'
#!/bin/bash
# Mock SSH for E2E testing

# Check if it's a GitHub SSH test
if [[ "$*" == *"git@github"* ]] && [[ "$*" == *"git-receive-pack"* ]]; then
    # Simulate successful SSH auth
    echo "Hi testuser! You've successfully authenticated, but GitHub does not provide shell access."
    exit 0
fi

# For other commands, just exit successfully
exit 0
EOF
    chmod +x "$HOME/bin/ssh"
}