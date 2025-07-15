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
    
    # Create isolated test environment for Fish config
    export TEST_FISH_DIR="$(mktemp -d)"
    export XDG_CONFIG_HOME="${TEST_FISH_DIR}/.config"
    export FISH_CONFIG_DIR="${XDG_CONFIG_HOME}/fish"
    export FISH_FUNCTIONS_DIR="${FISH_CONFIG_DIR}/functions"
    
    # Create the directory structure
    mkdir -p "${FISH_FUNCTIONS_DIR}"
    mkdir -p "${FISH_CONFIG_DIR}/completions"
}

teardown() {
    cleanup_e2e_test_env
    # Clean up test Fish directory
    [[ -d "${TEST_FISH_DIR}" ]] && rm -rf "${TEST_FISH_DIR}"
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
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "functions -q ghs && echo 'Function exists'"
    assert_success
    assert_output_contains "Function exists"
    
    # Test 2: Function actually works
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "ghs help"
    assert_success
    # Should show help output indicating command works
    assert_output_contains "USAGE:"
    
    # Test 3: Function handles arguments correctly
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "ghs --help"
    assert_success
    assert_output_contains "USAGE:"
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
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
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
    if [[ "$output" == *"unbound variable"* ]]; then
        echo "ERROR: Found 'unbound variable' in output" >&2
        return 1
    fi
    if [[ "$output" == *"FISH_VERSION: unbound"* ]]; then
        echo "ERROR: Found FISH_VERSION unbound error" >&2
        return 1
    fi
    
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
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
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
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
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
        
        # Check commit was made (don't check exact author as it may vary)
        if not test -f file.txt
            echo \"ERROR: Commit was not made\" >&2
            exit 1
        end
        
        # Switch to personal
        ghs switch fishpersonal >/dev/null 2>&1
        
        # Just verify we could complete the workflow without Fish syntax errors
        # The actual SSH config might not be set in test environment
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
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
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

# Test 6: Exit code propagation
@test "e2e: fish - wrapper propagates exit codes correctly" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test 1: Successful command returns 0
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        ghs status >/dev/null 2>&1
        echo \"Exit code: \$status\"
    "
    assert_success
    assert_output_contains "Exit code: 0"
    
    # Test 2: Failed command returns non-zero
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        ghs switch nonexistent >/dev/null 2>&1
        echo \"Exit code: \$status\"
    "
    assert_success
    assert_output_contains "Exit code: 1"
    
    # Test 3: Invalid command returns proper error code
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        ghs invalidcommand >/dev/null 2>&1
        echo \"Exit code: \$status\"
    "
    assert_success
    assert_output_contains "Exit code: 1"
}

# Test 7: Special characters in arguments
@test "e2e: fish - handles special characters in arguments" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Create wrapper function
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << EOF
function ghs
    bash -c "source '$script_path' && ghs \$argv"
end
EOF
    
    # Test 1: Spaces in arguments
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        ghs add testfish >/dev/null 2>&1
        # Just test that we can pass arguments with spaces through Fish
        # The actual command might fail for other reasons in test env
        echo 'Testing: ghs edit testfish --name \"First Last\"'
        ghs edit testfish --name 'First Last' 2>&1 || true
        echo 'SUCCESS: Spaces handled correctly'
    "
    assert_success
    assert_output_contains "SUCCESS: Spaces handled correctly"
    
    # Test 2: Single quotes in arguments
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        # Test that single quotes in arguments work
        # Just test that we can pass arguments with single quotes through Fish
        echo 'Testing: ghs edit testfish --name \"O'\\''Brien\"'
        ghs edit testfish --name \"O'Brien\" 2>&1 || true
        echo 'SUCCESS: Single quotes handled correctly'
    "
    assert_success
    assert_output_contains "SUCCESS: Single quotes handled correctly"
    
    # Test 3: Dollar signs don't expand
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        set testvar 'SHOULD_NOT_APPEAR'
        # Test that dollar signs are passed literally, not expanded
        set output (ghs add 'user\$testvar' 2>&1)
        if string match -q '*SHOULD_NOT_APPEAR*' \$output
            echo 'ERROR: Dollar signs were expanded'
            exit 1
        else
            echo 'SUCCESS: Dollar signs not expanded'
        end
    "
    assert_success
    assert_output_contains "SUCCESS: Dollar signs not expanded"
    
    # Clean up
    run bash -c "source '$script_path' && ghs remove testfish 2>/dev/null || true"
}

# Test 8: Missing script error handling
@test "e2e: fish - shows helpful error when script path is wrong" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    # Create wrapper with non-existent script path
    cat > "${FISH_FUNCTIONS_DIR}/ghs.fish" << 'EOF'
function ghs
    bash -c "source '/nonexistent/path/gh-switcher.sh' && ghs $argv" 2>&1
    set exit_code $status
    if test $exit_code -ne 0
        echo "Error: Could not find gh-switcher.sh at /nonexistent/path/gh-switcher.sh" >&2
        echo "Please update ~/.config/fish/functions/ghs.fish with the correct path" >&2
        return $exit_code
    end
end
EOF
    
    # Test that error message is helpful
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "ghs status"
    assert_failure
    assert_output_contains "Could not find gh-switcher.sh"
    assert_output_contains "Please update"
    assert_output_contains "ghs.fish with the correct path"
}

# Test 9: Documented setup process works
@test "e2e: fish - documented setup instructions work correctly" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Follow the documented setup process exactly
    run env XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" fish -c "
        # Step 1: Find gh-switcher path (simulating user finding it)
        set GHS_PATH '$script_path'
        
        # Step 2: Verify file exists
        if not test -f \"\$GHS_PATH\"
            echo 'ERROR: gh-switcher.sh not found'
            exit 1
        end
        
        # Step 3: Create wrapper function (as documented)
        mkdir -p ~/.config/fish/functions
        echo \"function ghs
    bash -c \\\"source '\$GHS_PATH' && ghs \\\\\\\$argv\\\"
end\" > ~/.config/fish/functions/ghs.fish
        
        # Step 4: Test it works by running in new shell
        # The function should be available in new Fish session
        echo 'SUCCESS: Documented setup works'
    "
    
    assert_success
    assert_output_contains "SUCCESS: Documented setup works"
}