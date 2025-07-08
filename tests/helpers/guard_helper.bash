#!/usr/bin/env bash

# Guard-specific test helpers for gh-switcher guard hooks testing
# Following the established patterns from test_helper.bash

# Setup guard test environment with isolated git repository
setup_guard_test_environment() {
    setup_test_environment
    
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
    
    # Ensure guard-hook.sh script is available for testing
    export TEST_GUARD_SCRIPT="$TEST_HOME/guard-hook.sh"
    cp "$BATS_TEST_DIRNAME/../../scripts/guard-hook.sh" "$TEST_GUARD_SCRIPT"
}

# Cleanup guard test environment
cleanup_guard_test_environment() {
    # Clean up any installed hooks
    if [[ -f "$TEST_GIT_REPO/.git/hooks/pre-commit" ]]; then
        rm -f "$TEST_GIT_REPO/.git/hooks/pre-commit"
    fi
    
    # Remove backup hooks
    find "$TEST_GIT_REPO/.git/hooks/" -name "pre-commit.backup.*" -type f -delete 2>/dev/null || true
    
    cleanup_test_environment
}

# Create a mock GitHub CLI that returns specific user
setup_mock_gh_user() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        # Mock unauthenticated state
        export GH_MOCK_UNAUTHENTICATED="1"
        return 0
    fi
    
    # Create mock gh command that returns specified user
    cat > "$TEST_HOME/gh" << EOF
#!/bin/bash
if [[ "\$1 \$2" == "auth status" ]]; then
    if [[ -n "\${GH_MOCK_UNAUTHENTICATED:-}" ]]; then
        exit 1
    fi
    echo "✓ Logged in to github.com as $username"
    exit 0
elif [[ "\$1 \$2 \$3" == "api user --jq" ]]; then
    if [[ -n "\${GH_MOCK_UNAUTHENTICATED:-}" ]]; then
        exit 1
    fi
    echo "$username"
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
}

# Setup project assignment for testing
setup_test_project_assignment() {
    local project="$1"
    local username="$2"
    
    echo "$project=$username" >> "$GH_PROJECT_CONFIG"
}

# Create existing pre-commit hook for testing backup functionality
create_existing_precommit_hook() {
    local hook_content="${1:-#!/bin/bash\necho \"Existing hook\"\n}"
    
    mkdir -p "$TEST_GIT_REPO/.git/hooks"
    echo -e "$hook_content" > "$TEST_GIT_REPO/.git/hooks/pre-commit"
    chmod +x "$TEST_GIT_REPO/.git/hooks/pre-commit"
}

# Assert that guard hook is installed
assert_guard_hook_installed() {
    local hook_file="$TEST_GIT_REPO/.git/hooks/pre-commit"
    
    [[ -f "$hook_file" ]] || {
        echo "Expected guard hook to be installed at $hook_file"
        return 1
    }
    
    [[ -L "$hook_file" ]] || {
        echo "Expected guard hook to be a symlink"
        return 1
    }
    
    local target=$(readlink "$hook_file")
    case "$target" in
        *guard-hook.sh)
            return 0
            ;;
        *)
            echo "Expected guard hook to link to guard-hook.sh, got: $target"
            return 1
            ;;
    esac
}

# Assert that guard hook is NOT installed
assert_guard_hook_not_installed() {
    local hook_file="$TEST_GIT_REPO/.git/hooks/pre-commit"
    
    if [[ -L "$hook_file" ]]; then
        local target=$(readlink "$hook_file")
        case "$target" in
            *guard-hook.sh)
                echo "Expected guard hook to NOT be installed, but found link to: $target"
                return 1
                ;;
        esac
    fi
    
    return 0
}

# Assert that backup hook exists
assert_backup_hook_exists() {
    local backup_count=$(find "$TEST_GIT_REPO/.git/hooks/" -name "pre-commit.backup.*" -type f | wc -l)
    
    if [[ "$backup_count" -eq 0 ]]; then
        echo "Expected backup hook to exist"
        return 1
    fi
    
    return 0
}

# Run guard command and capture output
run_guard_command() {
    cd "$TEST_GIT_REPO"
    run bash "$BATS_TEST_DIRNAME/../../gh-switcher.sh" guard "$@"
}

# Test guard hook execution directly
run_guard_hook() {
    cd "$TEST_GIT_REPO"
    
    # Set up environment variables that guard hook expects
    export GH_SWITCHER_PATH="$BATS_TEST_DIRNAME/../../gh-switcher.sh"
    
    run bash "$TEST_GUARD_SCRIPT"
}

# Mock git config for testing
setup_mock_git_config() {
    local name="$1"
    local email="$2"
    local scope="${3:-local}"
    
    cd "$TEST_GIT_REPO"
    
    if [[ "$scope" == "local" ]]; then
        git config user.name "$name" >/dev/null 2>&1
        git config user.email "$email" >/dev/null 2>&1
    else
        git config --global user.name "$name" >/dev/null 2>&1
        git config --global user.email "$email" >/dev/null 2>&1
    fi
}

# Clear git config for testing
clear_git_config() {
    local scope="${1:-local}"
    
    cd "$TEST_GIT_REPO"
    
    if [[ "$scope" == "local" ]]; then
        git config --unset user.name >/dev/null 2>&1 || true
        git config --unset user.email >/dev/null 2>&1 || true
    else
        git config --global --unset user.name >/dev/null 2>&1 || true
        git config --global --unset user.email >/dev/null 2>&1 || true
    fi
}

# Performance timing helper
time_command() {
    local start_time=$(date +%s%N)
    "$@"
    local exit_code=$?
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    echo "Command took ${duration}ms" >&2
    export LAST_COMMAND_DURATION_MS="$duration"
    
    return $exit_code
}

# Assert command completed within time limit
assert_command_fast() {
    local max_ms="${1:-100}"
    
    if [[ -z "${LAST_COMMAND_DURATION_MS:-}" ]]; then
        echo "No timing data available. Use time_command to measure performance."
        return 1
    fi
    
    if [[ "$LAST_COMMAND_DURATION_MS" -gt "$max_ms" ]]; then
        echo "Command took ${LAST_COMMAND_DURATION_MS}ms, expected <${max_ms}ms"
        return 1
    fi
    
    return 0
}