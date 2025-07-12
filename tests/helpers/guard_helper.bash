#!/usr/bin/env bash

# Simplified guard test helpers following project's "simple over complex" philosophy

# Setup guard test environment with isolated git repository
setup_guard_test_environment() {
    setup_test_environment
    
    # Set up ghs command FIRST before anything else
    setup_hook_test_environment
    
    # Create isolated git repository for hook testing
    export TEST_GIT_REPO="$TEST_HOME/test-repo"
    mkdir -p "$TEST_GIT_REPO"
    cd "$TEST_GIT_REPO"
    
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    # Create initial commit so repository is valid
    echo "# Test Repository" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Ensure any old hooks are removed
    rm -f "$TEST_GIT_REPO/.git/hooks/pre-commit"
    
    # Guard functionality is integrated into main script
    export TEST_GUARD_SCRIPT="$BATS_TEST_DIRNAME/../../gh-switcher.sh"
}

# Cleanup guard test environment
cleanup_guard_test_environment() {
    cleanup_test_environment
}

# Create a mock GitHub CLI that returns specific user
setup_mock_gh_user() {
    local username="${1:-}"
    
    if [[ -z "$username" ]]; then
        # Mock unauthenticated state
        export GH_MOCK_UNAUTHENTICATED="1"
        return 0
    fi
    
    # Create simple mock gh command
    cat > "$TEST_HOME/gh" << EOF
#!/bin/bash
if [[ "\$1 \$2" == "auth status" ]]; then
    [[ -z "\${GH_MOCK_UNAUTHENTICATED:-}" ]] || exit 1
    exit 0
elif [[ "\$1 \$2 \$3 \$4" == "api user -q .login" ]]; then
    [[ -z "\${GH_MOCK_UNAUTHENTICATED:-}" ]] || exit 1
    echo "$username"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
}

# Setup project assignment for testing
setup_test_project_assignment() {
    local project="$1"
    local username="$2"
    echo "$project=$username" >> "$GH_PROJECT_CONFIG"
    
    # Also create a basic profile for the user if it doesn't exist
    if ! grep -q "^${username}	" "$GH_USER_PROFILES" 2>/dev/null; then
        printf "%s\tv5\t%s\t%s@example.com\t\tgithub.com\n" "$username" "$username" "$username" >> "$GH_USER_PROFILES"
    fi
}

# Create existing pre-commit hook for testing backup functionality
create_existing_precommit_hook() {
    local hook_content="${1:-#!/bin/bash\necho \"Existing hook\"\n}"
    mkdir -p "$TEST_GIT_REPO/.git/hooks"
    echo -e "$hook_content" > "$TEST_GIT_REPO/.git/hooks/pre-commit"
    chmod +x "$TEST_GIT_REPO/.git/hooks/pre-commit"
}

# Run guard command and capture output (inside git repo)
run_guard_command() {
    cd "$TEST_GIT_REPO"
    run env GH_PROJECT_CONFIG="$GH_PROJECT_CONFIG" \
        GH_USERS_CONFIG="$GH_USERS_CONFIG" \
        GH_USER_PROFILES="$GH_USER_PROFILES" \
        bash "$BATS_TEST_DIRNAME/../../gh-switcher.sh" guard "$@"
}

# Run guard command without changing directory (for testing outside git repo)
run_guard_command_here() {
    run bash "$BATS_TEST_DIRNAME/../../gh-switcher.sh" guard "$@"
}

# Setup proper hook test environment with working ghs command
setup_hook_test_environment() {
    # Create a proper ghs executable in test PATH
    mkdir -p "$TEST_HOME/bin"
    
    # We need to expand the path now, not when the script runs
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    # Copy the actual script to be our ghs command
    cp "$script_path" "$TEST_HOME/bin/ghs"
    chmod +x "$TEST_HOME/bin/ghs"
    export PATH="$TEST_HOME/bin:$PATH"
}

# Run guard hook directly for testing
run_guard_hook() {
    cd "$TEST_GIT_REPO"
    
    # Run the actual pre-commit hook
    run bash "$TEST_GIT_REPO/.git/hooks/pre-commit"
}