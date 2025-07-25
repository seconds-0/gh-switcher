#!/usr/bin/env bats

# E2E Test - VS Code Bash Environment
# Tests gh-switcher in VS Code terminal to prevent environment-specific bugs

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
    create_mock_gh
    create_test_ssh_keys
}

teardown() {
    cleanup_e2e_test_env
}

# Test 1: VS Code Bash - No crash with unset variables (would have caught our bug)
@test "e2e: VS Code bash - no crash with unset variables" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # VS Code environment with potentially unset variables
    run bash -c "
        set -euo pipefail
        export TERM_PROGRAM=vscode
        export VSCODE_INJECTION=1
        export VSCODE_GIT_IPC_HANDLE='/tmp/vscode-git-$$'
        
        # This variable caused our production crash
        unset VSCODE_SHELL_ENV_REPORTING 2>/dev/null || true
        
        # Should not crash when sourcing
        source '$script_path'
        
        # Should not crash when running commands
        ghs status
    "
    
    assert_success
}

# Test 2: VS Code Bash - Basic operations work
@test "e2e: VS Code bash - basic user operations work" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        # Set up VS Code environment
        export TERM_PROGRAM=vscode
        export VSCODE_INJECTION=1
        export VSCODE_GIT_IPC_HANDLE='/tmp/vscode-git-$$'
        export GIT_ASKPASS='$HOME/.vscode/extensions/git/askpass.sh'
        
        source '$script_path'
        
        # Add user
        if ! ghs add vscodeuser >/dev/null 2>&1; then
            echo 'ERROR: Failed to add user vscodeuser' >&2
            exit 1
        fi
        
        # Create profile for the user (needed for git config)
        echo 'vscodeuser|VS Code User|vscode@example.com||github.com' >> \"$GH_USER_PROFILES\"
        
        # Switch to user
        if ! ghs switch vscodeuser >/dev/null 2>&1; then
            echo 'ERROR: Failed to switch to user vscodeuser' >&2
            exit 1
        fi
        
        # Verify switch worked - capture status to avoid broken pipe
        status_output=\$(ghs status 2>&1)
        if ! echo \"\$status_output\" | grep -q vscodeuser; then
            echo 'ERROR: Status does not show vscodeuser' >&2
            echo \"Status output was: \$status_output\" >&2
            exit 1
        fi
        
        # Clean up
        ghs remove vscodeuser >/dev/null 2>&1
        
        echo 'All operations succeeded'
    "
    
    assert_success
    assert_output_contains "All operations succeeded"
}

# Test 3: VS Code Bash - Git operations work with VS Code's Git environment
@test "e2e: VS Code bash - git config updates work" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        # Set up VS Code Git environment
        export TERM_PROGRAM=vscode
        export VSCODE_GIT_IPC_HANDLE='/tmp/vscode-git-$$'
        export VSCODE_GIT_ASKPASS_NODE='/usr/local/bin/node'
        export VSCODE_GIT_ASKPASS_MAIN='$HOME/.vscode/extensions/git/dist/askpass-main.js'
        export GIT_ASKPASS='$HOME/.vscode/extensions/git/askpass.sh'
        export BATS_TEST_FILENAME='test_vscode_bash.bats'  # Suppress VSCode warning in test
        
        source '$script_path'
        
        # Create a test git repo first
        test_repo=\$(mktemp -d)
        cd \"\$test_repo\"
        git init >/dev/null 2>&1
        
        # Add user first
        ghs add gituser >/dev/null 2>&1
        
        # Create profile for the user (needed for git config)
        printf 'gituser\tGit User\tgit@vscode.test\t\tgithub.com\n' > \"$GH_USER_PROFILES\"
        
        # Switch to user - this should apply the profile
        ghs switch gituser >/dev/null 2>&1
        
        # Debug: show what profiles exist
        echo \"Profiles in file:\" >&2
        cat \"$GH_USER_PROFILES\" >&2
        
        # Verify git config was updated
        git_name=\$(git config user.name)
        git_email=\$(git config user.email)
        
        if [[ \"\$git_name\" != 'Git User' ]]; then
            echo \"ERROR: Git name not set correctly: '\$git_name'\" >&2
            echo \"Git config user.name: \$(git config --list | grep user.name)\" >&2
            exit 1
        fi
        
        if [[ \"\$git_email\" != 'git@vscode.test' ]]; then
            echo \"ERROR: Git email not set correctly: '\$git_email'\" >&2
            exit 1
        fi
        
        # Clean up
        cd /
        rm -rf \"\$test_repo\"
        
        echo 'Git config updated correctly'
    "
    
    assert_success
    assert_output_contains "Git config updated correctly"
}

# Test 4: VS Code Bash - Guard hooks work in VS Code terminal
@test "e2e: VS Code bash - guard hooks install and work" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        # VS Code environment
        export TERM_PROGRAM=vscode
        export VSCODE_INJECTION=1
        
        source '$script_path'
        
        # Create test repo
        test_repo=\$(mktemp -d)
        cd \"\$test_repo\"
        git init >/dev/null 2>&1
        
        # Install guard hooks
        if ! ghs guard install >/dev/null 2>&1; then
            echo 'ERROR: Failed to install guard hooks' >&2
            exit 1
        fi
        
        # Verify hook exists
        if [[ ! -f .git/hooks/pre-commit ]]; then
            echo 'ERROR: Pre-commit hook not created at .git/hooks/pre-commit' >&2
            exit 1
        fi
        
        # Debug: show hook contents
        echo \"Hook contents:\" >&2
        cat .git/hooks/pre-commit >&2
        
        # Verify hook contains GHS_GUARD_HOOK marker
        if ! grep -q 'GHS_GUARD_HOOK' .git/hooks/pre-commit; then
            echo 'ERROR: Pre-commit hook does not contain GHS_GUARD_HOOK marker' >&2
            exit 1
        fi
        
        # Verify it checks for account mismatch
        if ! grep -q 'Account mismatch detected' .git/hooks/pre-commit; then
            echo 'ERROR: Pre-commit hook does not contain account mismatch check' >&2
            exit 1
        fi
        
        # Clean up
        cd /
        rm -rf \"\$test_repo\"
        
        echo 'Guard hooks work in VS Code'
    "
    
    assert_success
    assert_output_contains "Guard hooks work in VS Code"
}

# Test 5: VS Code Bash - No warning needed anymore (functionality verified in other tests)
@test "e2e: VS Code bash - works seamlessly without warnings" {
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Test that VSCode terminal works without any warnings
    run bash -c "
        export TERM_PROGRAM=vscode
        source '$script_path'
        output=\$(ghs status 2>&1)
        if echo \"\$output\" | grep -qi 'warning\\|cannot be\\|detected'; then
            echo 'ERROR: Unexpected warning shown'
            exit 1
        else
            echo 'SUCCESS: No warnings in VSCode terminal'
        fi
    "
    
    assert_success
    assert_output_contains "SUCCESS: No warnings in VSCode terminal"
}