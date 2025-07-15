#!/usr/bin/env bats

# E2E Test - Fish Shell Environment
# Tests gh-switcher wrapper function in Fish shell
# These tests verify:
# 1. Fish users can actually use gh-switcher
# 2. The wrapper function approach works correctly
# 3. Fish-specific environment handling doesn't break

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
    create_mock_gh
    create_test_ssh_keys
    
    # Store original Fish config path
    export FISH_CONFIG_DIR="${HOME}/.config/fish"
    export FISH_FUNCTIONS_DIR="${FISH_CONFIG_DIR}/functions"
}

teardown() {
    cleanup_e2e_test_env
    # Clean up Fish functions if they exist
    rm -f "${FISH_FUNCTIONS_DIR}/ghs.fish"
}

# Test 1: Fish users can install and use the wrapper function
@test "e2e: fish - users can install wrapper function that survives shell restart" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function with correct path
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test 1: Function loads in new Fish session
    run fish -c "functions -q ghs && echo 'Function exists'"
    assert_success
    assert_output_contains "Function exists"
    
    # Test 2: Function actually works
    run fish -c "ghs status"
    assert_success
    # Should show status output (not an error)
    assert_output_contains "Current GitHub user:" || assert_output_contains "No current user"
    
    # Test 3: Function handles arguments correctly
    run fish -c "ghs --help"
    assert_success
    assert_output_contains "Usage:"
}

# Test 2: Fish-specific environment variables don't break gh-switcher
@test "e2e: fish - handles Fish environment variables without errors" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test with Fish-specific environment
    run fish -c "
        # Set Fish-specific variables that might cause issues
        set -x FISH_VERSION \$FISH_VERSION
        set -x fish_greeting ''
        set -x __fish_git_prompt_showdirtystate 'yes'
        
        # These should not affect gh-switcher
        ghs add fishenvtest >/dev/null 2>&1
        ghs status 2>&1
    "
    
    assert_success
    # Should not have any bash errors about Fish variables
    refute_output_contains "unbound variable"
    refute_output_contains "FISH_VERSION"
    
    # Clean up
    run bash -c "source '$script_path' && ghs remove fishenvtest 2>/dev/null || true"
}

# Test 3: Fish syntax in arguments doesn't break the wrapper
@test "e2e: fish - handles Fish syntax in command arguments" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test various Fish-specific syntax that might cause issues
    run fish -c "
        # Test 1: Spaces in arguments
        ghs add 'user with spaces' 2>&1 | string match -r 'Invalid username format'
        
        # Test 2: Special characters that Fish might interpret
        ghs add 'user\$var' 2>&1 | string match -r 'Invalid username format'
        
        # Test 3: Command substitution syntax differences
        set testuser (echo fishtest)
        ghs add \$testuser >/dev/null 2>&1
        
        # Verify it worked
        if not ghs users | string match -q '*fishtest*'
            echo 'ERROR: User not added correctly'
            exit 1
        end
        
        # Clean up
        ghs remove fishtest >/dev/null 2>&1
        
        echo 'SUCCESS: Fish syntax handled correctly'
    "
    
    assert_success
    assert_output_contains "SUCCESS: Fish syntax handled correctly"
}

# Test 4: Real-world Fish user workflow
@test "e2e: fish - complete workflow with git operations" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Create a test git repo
    local test_repo
    test_repo=$(mktemp -d)
    
    # Run complete workflow in Fish
    run fish -c "
        cd '$test_repo'
        git init >/dev/null 2>&1
        
        # Add two users
        ghs add fishwork --ssh-key ~/.ssh/testuser1_ed25519 >/dev/null 2>&1
        ghs add fishpersonal --ssh-key ~/.ssh/testuser2_ed25519 >/dev/null 2>&1
        
        # Set profiles
        ghs edit fishwork --name 'Work Account' --email 'work@company.com' >/dev/null 2>&1
        ghs edit fishpersonal --name 'Personal' --email 'me@personal.com' >/dev/null 2>&1
        
        # Switch to work account
        ghs switch fishwork >/dev/null 2>&1
        
        # Make a commit
        echo 'test' > file.txt
        git add file.txt
        git commit -m 'Work commit' >/dev/null 2>&1
        
        # Check commit author
        set author (git log -1 --format='%an <%ae>')
        if not string match -q '*Work Account <work@company.com>*' \$author
            echo \"ERROR: Wrong commit author: \$author\" >&2
            exit 1
        end
        
        # Switch to personal
        ghs switch fishpersonal >/dev/null 2>&1
        
        # Verify SSH command was updated
        set ssh_cmd (git config core.sshCommand)
        if not string match -q '*testuser2_ed25519*' \$ssh_cmd
            echo \"ERROR: SSH key not updated: \$ssh_cmd\" >&2
            exit 1
        end
        
        echo 'SUCCESS: Complete Fish workflow works'
    "
    
    assert_success
    assert_output_contains "SUCCESS: Complete Fish workflow works"
    
    # Clean up
    rm -rf "$test_repo"
    run bash -c "
        source '$script_path'
        ghs remove fishwork 2>/dev/null || true
        ghs remove fishpersonal 2>/dev/null || true
    "
}

# Test 5: Fish completions documentation
@test "e2e: fish - verify completion setup instructions work" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Create basic completions
    mkdir -p "${FISH_CONFIG_DIR}/completions"
    cat > "${FISH_CONFIG_DIR}/completions/ghs.fish" << 'EOF'
# Basic gh-switcher completions for Fish
complete -c ghs -f
complete -c ghs -n "__fish_use_subcommand" -a "status" -d "Show current GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "switch" -d "Switch GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "add" -d "Add a new GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "remove" -d "Remove a GitHub user"
complete -c ghs -n "__fish_use_subcommand" -a "users" -d "List all users"
complete -c ghs -n "__fish_use_subcommand" -a "guard" -d "Manage guard hooks"
EOF
    
    # Test completions work
    run fish -c "
        # Load completions
        source '${FISH_CONFIG_DIR}/completions/ghs.fish'
        
        # This would normally trigger tab completion
        # We just verify the completion functions are loaded
        complete -c ghs -n '__fish_use_subcommand' | head -n 1 >/dev/null
        if test \$status -eq 0
            echo 'Completions loaded successfully'
        else
            echo 'ERROR: Completions failed to load'
            exit 1
        end
    "
    
    assert_success
    assert_output_contains "Completions loaded successfully"
    
    # Clean up
    rm -f "${FISH_CONFIG_DIR}/completions/ghs.fish"
}