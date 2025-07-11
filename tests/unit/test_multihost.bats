#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_environment
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    
    # Source the script only if functions are not already loaded
    if ! type validate_host >/dev/null 2>&1; then
        source "$PROJECT_ROOT/gh-switcher.sh"
    fi
}

teardown() {
    cleanup_test_environment
}

# =============================================================================
# Host Validation Tests
# =============================================================================

@test "validate_host accepts valid formats" {
    run validate_host "github.com"
    assert_success
    
    run validate_host "github.company.com"
    assert_success
    
    run validate_host "github.internal.corp.net"
    assert_success
}

@test "validate_host rejects invalid formats" {
    run validate_host "github"
    assert_failure
    assert_output_contains "Host must be a fully qualified domain"
    
    run validate_host "github.com:8080"
    assert_failure
    assert_output_contains "Host should not include port"
    
    run validate_host "https://github.com"
    assert_failure
    assert_output_contains "Host should not include protocol"
}

@test "validate_host rejects empty host" {
    run validate_host ""
    assert_failure
    assert_output_contains "Host cannot be empty"
}

@test "validate_host rejects overly long host" {
    local long_host=""
    for i in {1..30}; do
        long_host="${long_host}verylongsubdomain."
    done
    long_host="${long_host}github.com"
    
    run validate_host "$long_host"
    assert_failure
    assert_output_contains "Host too long"
}

# =============================================================================
# Profile Format Tests
# =============================================================================


@test "profile_get handles v4 format with custom host" {
    # Create v4 profile
    echo "work|v4|Work User|work@company.com|~/.ssh/work|github.company.com" > "$GH_USER_PROFILES"
    
    run profile_get "work"
    assert_success
    assert_output_contains "host:github.company.com"
}

@test "profile_create creates v4 format with host" {
    run profile_create "enterprise" "Enterprise User" "enterprise@company.com" "~/.ssh/enterprise" "github.enterprise.com"
    assert_success
    
    # Check created profile
    run cat "$GH_USER_PROFILES"
    assert_output_contains "|v4|"
    assert_output_contains "|github.enterprise.com"
}

@test "profile_create defaults to github.com when host not specified" {
    run profile_create "testuser" "Test User" "test@example.com" "~/.ssh/test"
    assert_success
    
    # Check created profile
    run cat "$GH_USER_PROFILES"
    assert_output_contains "|v4|"
    assert_output_contains "|github.com"
}

@test "profile_create generates correct default email for enterprise" {
    run profile_create "workuser" "Work User" "" "" "github.company.com"
    assert_success
    
    run profile_get "workuser"
    assert_success
    assert_output_contains "email:workuser@github.company.com"
}

@test "profile_create generates correct default email for github.com" {
    run profile_create "publicuser" "Public User" "" "" "github.com"
    assert_success
    
    run profile_get "publicuser"
    assert_success
    assert_output_contains "email:publicuser@users.noreply.github.com"
}

# =============================================================================
# Command Tests
# =============================================================================

@test "cmd_add accepts --host parameter" {
    run ghs add enterprise --host github.company.com
    assert_success
    assert_output_contains "Added enterprise"
    
    # Verify profile has host
    run profile_get "enterprise"
    assert_output_contains "host:github.company.com"
}

@test "cmd_add validates host format" {
    run ghs add testuser --host "invalid host"
    assert_failure
    assert_output_contains "Invalid host format"
}

@test "cmd_add shows host when not github.com" {
    run ghs add enterprise --host github.enterprise.com
    assert_success
    assert_output_contains "Host: github.enterprise.com"
}

@test "cmd_edit can update host" {
    # Add user first
    ghs add testuser
    
    # Edit host
    run ghs edit testuser --host github.enterprise.com
    assert_success
    
    # Verify update
    run profile_get "testuser"
    assert_output_contains "host:github.enterprise.com"
}

@test "cmd_show displays host for non-github.com" {
    # Create user with enterprise host
    profile_create "enterprise" "Enterprise User" "enterprise@company.com" "" "github.company.com"
    user_add "enterprise"
    
    run ghs show enterprise
    assert_success
    assert_output_contains "Host: github.company.com"
}

@test "cmd_show doesn't display host for github.com" {
    # Create user with default host
    profile_create "public" "Public User" "public@example.com" "" "github.com"
    user_add "public"
    
    run ghs show public
    assert_success
    # Should not show host line for github.com
    ! assert_output_contains "Host: github.com"
}

@test "cmd_users shows host for non-github.com" {
    user_add "personal"
    profile_create "personal" "Personal" "personal@example.com" "" "github.com"
    
    user_add "work"
    profile_create "work" "Work" "work@company.com" "" "github.company.com"
    
    run ghs users
    assert_success
    assert_output_contains "1. personal [HTTPS]"
    assert_output_contains "2. work [HTTPS] (github.company.com)"
}

@test "cmd_switch shows host info for enterprise" {
    user_add "enterprise"
    profile_create "enterprise" "Enterprise" "enterprise@company.com" "" "github.enterprise.com"
    
    # Mock gh to return current user
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
    echo "enterprise"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    run ghs switch enterprise
    assert_success
    assert_output_contains "Switching to enterprise on github.enterprise.com"
    assert_output_contains "gh auth status --hostname github.enterprise.com"
}

# =============================================================================
# SSH Testing with Host
# =============================================================================

@test "test_ssh_auth uses custom host" {
    # Mock SSH for enterprise
    cat > "$TEST_HOME/ssh" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "-T git@github.enterprise.com" ]]; then
    echo "Hi user! You've successfully authenticated" >&2
    exit 1
fi
EOF
    chmod +x "$TEST_HOME/ssh"
    export PATH="$TEST_HOME:$PATH"
    
    run test_ssh_auth "$TEST_HOME/.ssh/key" "github.enterprise.com"
    assert_success
}

@test "cmd_test_ssh shows host for enterprise users" {
    # Create enterprise user
    user_add "enterprise"
    profile_create "enterprise" "Enterprise" "enterprise@company.com" "$TEST_HOME/.ssh/enterprise" "github.enterprise.com"
    
    # Create SSH key
    mkdir -p "$TEST_HOME/.ssh"
    touch "$TEST_HOME/.ssh/enterprise"
    chmod 600 "$TEST_HOME/.ssh/enterprise"
    
    # Mock SSH
    cat > "$TEST_HOME/ssh" << 'EOF'
#!/bin/bash
echo "Hi enterprise! You've successfully authenticated" >&2
exit 1
EOF
    chmod +x "$TEST_HOME/ssh"
    export PATH="$TEST_HOME:$PATH"
    
    run ghs test-ssh enterprise
    assert_success
    assert_output_contains "Host: github.enterprise.com"
}

# =============================================================================
# Migration Tests
# =============================================================================



# =============================================================================
# Guard Hook Tests
# =============================================================================

#@test "guard test shows host info for enterprise assignment" {
#    # Create project assignment
#    echo "testproject:enterprise" >> "$GH_PROJECT_CONFIG"
#    
#    # Create enterprise profile
#    user_add "enterprise"
#    profile_create "enterprise" "Enterprise" "enterprise@company.com" "" "github.enterprise.com"
#    
#    # Mock git for project detection
#    cat > "$TEST_HOME/git" << 'EOF'
##!/bin/bash
#if [[ "$1" == "rev-parse" && "$2" == "--show-toplevel" ]]; then
#    echo "/path/to/testproject"
#    exit 0
#fi
## Pass through for config commands
#/usr/bin/git "$@"
#EOF
#    chmod +x "$TEST_HOME/git"
#    export PATH="$TEST_HOME:$PATH"
#    
#    # Mock gh to be authenticated
#    cat > "$TEST_HOME/gh" << 'EOF'
##!/bin/bash
#if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
#    echo "enterprise"
#    exit 0
#fi
#exit 1
#EOF
#    chmod +x "$TEST_HOME/gh"
#    
#    run guard_test
#    assert_success
#    assert_output_contains "Note: This profile is for host: github.enterprise.com"
#    assert_output_contains "gh auth status --hostname github.enterprise.com"
#}

#@test "guard test shows correct auth command for enterprise" {
#    # Create project assignment
#    echo "testproject:enterprise" >> "$GH_PROJECT_CONFIG"
#    
#    # Create enterprise profile
#    user_add "enterprise"
#    profile_create "enterprise" "Enterprise" "enterprise@company.com" "" "github.enterprise.com"
#    
#    # Mock git and gh to simulate no auth
#    cat > "$TEST_HOME/git" << 'EOF'
##!/bin/bash
#if [[ "$1" == "rev-parse" && "$2" == "--show-toplevel" ]]; then
#    echo "/path/to/testproject"
#    exit 0
#fi
#if [[ "$1" == "config" ]]; then
#    if [[ "$2" == "user.name" ]]; then
#        echo "Enterprise User"
#        exit 0
#    elif [[ "$2" == "user.email" ]]; then
#        echo "enterprise@company.com"
#        exit 0
#    fi
#fi
#/usr/bin/git "$@"
#EOF
#    chmod +x "$TEST_HOME/git"
#    export PATH="$TEST_HOME:$PATH"
#    
#    cat > "$TEST_HOME/gh" << 'EOF'
##!/bin/bash
#exit 1
#EOF
#    chmod +x "$TEST_HOME/gh"
#    
#    run guard_test
#    assert_success
#    assert_output_contains "gh auth login --hostname github.enterprise.com"
#}