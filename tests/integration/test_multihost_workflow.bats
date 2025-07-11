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

@test "complete workflow with multiple hosts" {
    # Mock SSH for both hosts
    cat > "$TEST_HOME/ssh" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "-T git@github.com" ]] || [[ "$*" =~ "-T git@github.company.com" ]]; then
    echo "Hi! You've successfully authenticated" >&2
    exit 1
fi
EOF
    chmod +x "$TEST_HOME/ssh"
    export PATH="$TEST_HOME:$PATH"
    
    # Add github.com user
    run ghs add personal --ssh-key "$TEST_ED25519_KEY"
    assert_success
    assert_output_contains "Added personal"
    
    # Add enterprise user
    run ghs add work --host github.company.com --ssh-key "$TEST_RSA_KEY"
    assert_success
    assert_output_contains "Added work"
    assert_output_contains "Host: github.company.com"
    
    # List shows both with hosts
    run ghs users
    assert_success
    assert_output_contains "personal [SSH]"
    assert_output_contains "work [SSH] (github.company.com)"
    
    # Show displays host for enterprise
    run ghs show work
    assert_success
    assert_output_contains "Host: github.company.com"
    
    # Show doesn't display host for github.com
    run ghs show personal
    assert_success
    ! assert_output_contains "Host:"
    
    # Switch to enterprise shows host info
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
    echo "work"
fi
EOF
    chmod +x "$TEST_HOME/gh"
    
    run ghs switch work
    assert_success
    assert_output_contains "Switching to work on github.company.com"
    assert_output_contains "gh auth status --hostname github.company.com"
}

@test "v3 to v4 migration on edit" {
    # Create v3 profile manually
    echo "olduser|v3|Old User|old@example.com|~/.ssh/old" > "$GH_USER_PROFILES"
    user_add "olduser"
    
    # Edit triggers migration
    run ghs edit olduser --name "Updated User"
    assert_success
    
    # Check migrated to v4
    run cat "$GH_USER_PROFILES"
    assert_output_contains "|v4|"
    assert_output_contains "|github.com"
    
    # Verify still works
    run profile_get "olduser"
    assert_success
    assert_output_contains "name:Updated User"
    assert_output_contains "host:github.com"
}

@test "SSH testing respects host configuration" {
    # Create users for different hosts
    user_add "gh-user"
    profile_create "gh-user" "GitHub User" "gh@example.com" "$TEST_ED25519_KEY" "github.com"
    
    user_add "ent-user"
    profile_create "ent-user" "Enterprise User" "ent@company.com" "$TEST_RSA_KEY" "github.enterprise.com"
    
    # Mock SSH to distinguish between hosts
    cat > "$TEST_HOME/ssh" << 'EOF'
#!/bin/bash
if [[ "$*" =~ "-T git@github.com" ]]; then
    echo "Hi gh-user! You've successfully authenticated to GitHub" >&2
    exit 1
elif [[ "$*" =~ "-T git@github.enterprise.com" ]]; then
    echo "Hi ent-user! You've successfully authenticated to Enterprise" >&2
    exit 1
fi
exit 255
EOF
    chmod +x "$TEST_HOME/ssh"
    export PATH="$TEST_HOME:$PATH"
    
    # Test github.com user
    run ghs test-ssh gh-user
    assert_success
    assert_output_contains "Host: github.com"
    assert_output_contains "SSH authentication successful"
    
    # Test enterprise user
    run ghs test-ssh ent-user
    assert_success
    assert_output_contains "Host: github.enterprise.com"
    assert_output_contains "SSH authentication successful"
}

@test "project assignment with enterprise users" {
    # Create enterprise user
    user_add "enterprise"
    profile_create "enterprise" "Enterprise" "enterprise@company.com" "" "github.enterprise.com"
    
    # Create test git repo
    mkdir -p "$TEST_HOME/project"
    cd "$TEST_HOME/project"
    git init >/dev/null 2>&1
    git config user.name "Enterprise User"
    git config user.email "enterprise@company.com"
    
    # Assign enterprise user
    run ghs assign enterprise
    assert_success
    
    # Mock for guard test
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
    echo "enterprise"
fi
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    # Guard test should show enterprise host
    run ghs guard test
    assert_success
    assert_output_contains "Note: This profile is for host: github.enterprise.com"
}

@test "different default emails for different hosts" {
    # Add user for github.com without email
    run ghs add ghuser
    assert_success
    
    run profile_get ghuser
    assert_success
    assert_output_contains "email:ghuser@users.noreply.github.com"
    
    # Add user for enterprise without email
    run ghs add entuser --host github.company.com
    assert_success
    
    run profile_get entuser
    assert_success
    assert_output_contains "email:entuser@github.company.com"
}

@test "host validation prevents common mistakes" {
    # Protocol prefix
    run ghs add user1 --host https://github.com
    assert_failure
    assert_output_contains "Host should not include protocol"
    
    # Port suffix
    run ghs add user2 --host github.com:443
    assert_failure
    assert_output_contains "Host should not include port"
    
    # Not fully qualified
    run ghs add user3 --host github
    assert_failure
    assert_output_contains "Host must be a fully qualified domain"
}

@test "switching between users on different hosts" {
    # Setup users
    user_add "personal"
    profile_create "personal" "Personal" "personal@example.com" "" "github.com"
    
    user_add "work"
    profile_create "work" "Work" "work@company.com" "" "github.work.com"
    
    # Mock gh
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
echo "personal"
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    # Create test repo
    mkdir -p "$TEST_HOME/repo"
    cd "$TEST_HOME/repo"
    git init
    
    # Switch to personal (github.com)
    run ghs switch personal
    assert_success
    assert_output_contains "Switching to personal on github.com"
    ! assert_output_contains "gh auth status"  # No special message for github.com
    
    # Switch to work (enterprise)
    run ghs switch work
    assert_success
    assert_output_contains "Switching to work on github.work.com"
    assert_output_contains "gh auth status --hostname github.work.com"
    assert_output_contains "gh auth login --hostname github.work.com"
}