#!/usr/bin/env bash

# Git testing helper for gh-switcher testing
# Provides git repository creation and testing utilities

# Create a test git repository
create_test_git_repo() {
    local repo_name="${1:-test_repo}"
    local repo_path="$TEST_HOME/$repo_name"
    
    mkdir -p "$repo_path"
    cd "$repo_path"
    
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    echo "$repo_path"
}

# Create a git repository with specific user configuration
create_git_repo_with_config() {
    local repo_name="$1"
    local user_name="$2"
    local user_email="$3"
    local repo_path
    
    repo_path=$(create_test_git_repo "$repo_name")
    cd "$repo_path"
    
    git config user.name "$user_name"
    git config user.email "$user_email"
    
    echo "$repo_path"
}

# Create a git repository with SSH configuration
create_git_repo_with_ssh() {
    local repo_name="$1"
    local ssh_key_path="$2"
    local repo_path
    
    repo_path=$(create_test_git_repo "$repo_name")
    cd "$repo_path"
    
    git config core.sshCommand "ssh -i '$ssh_key_path' -o IdentitiesOnly=yes"
    
    echo "$repo_path"
}

# Set up a bare git repository (for testing remote operations)
create_bare_git_repo() {
    local repo_name="${1:-bare_repo}"
    local repo_path="$TEST_HOME/$repo_name.git"
    
    mkdir -p "$repo_path"
    cd "$repo_path"
    git init --bare >/dev/null 2>&1
    
    echo "$repo_path"
}

# Clone a repository with SSH configuration
clone_repo_with_ssh() {
    local source_repo="$1"
    local target_name="$2"
    local ssh_key_path="$3"
    local target_path="$TEST_HOME/$target_name"
    
    git -c core.sshCommand="ssh -i '$ssh_key_path' -o IdentitiesOnly=yes" \
        clone "$source_repo" "$target_path" >/dev/null 2>&1
    
    echo "$target_path"
}

# Assert that git repository exists and is valid
assert_git_repo_exists() {
    local repo_path="$1"
    
    [[ -d "$repo_path/.git" ]] || {
        echo "Expected git repository to exist at: $repo_path"
        return 1
    }
    
    cd "$repo_path" && git status >/dev/null 2>&1 || {
        echo "Git repository appears to be invalid: $repo_path"
        return 1
    }
}

# Assert that we're currently in a git repository
assert_in_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1 || {
        echo "Expected to be in a git repository, but git status failed"
        echo "Current directory: $(pwd)"
        return 1
    }
}

# Assert that we're NOT in a git repository
assert_not_in_git_repo() {
    ! git rev-parse --git-dir >/dev/null 2>&1 || {
        echo "Expected to NOT be in a git repository, but git status succeeded"
        echo "Current directory: $(pwd)"
        return 1
    }
}

# Assert that git config has specific local value
assert_git_local_config() {
    local config_key="$1"
    local expected_value="$2"
    local actual_value
    
    actual_value=$(git config --local --get "$config_key" 2>/dev/null || echo "")
    [[ "$actual_value" == "$expected_value" ]] || {
        echo "Expected local git config '$config_key' to be '$expected_value', got '$actual_value'"
        return 1
    }
}

# Assert that git config has specific global value
assert_git_global_config() {
    local config_key="$1"
    local expected_value="$2"
    local actual_value
    
    actual_value=$(git config --global --get "$config_key" 2>/dev/null || echo "")
    [[ "$actual_value" == "$expected_value" ]] || {
        echo "Expected global git config '$config_key' to be '$expected_value', got '$actual_value'"
        return 1
    }
}

# Assert that SSH command is configured in git
assert_git_ssh_configured() {
    local expected_key_path="$1"
    local ssh_command
    
    ssh_command=$(git config --get core.sshCommand 2>/dev/null || echo "")
    [[ "$ssh_command" == *"$expected_key_path"* ]] || {
        echo "Expected git SSH command to include '$expected_key_path', got '$ssh_command'"
        return 1
    }
}

# Assert that no SSH command is configured in git
assert_git_ssh_not_configured() {
    local ssh_command
    
    ssh_command=$(git config --get core.sshCommand 2>/dev/null || echo "")
    [[ -z "$ssh_command" ]] || {
        echo "Expected no git SSH command, but found: $ssh_command"
        return 1
    }
}

# Clear all git configuration (local and global)
clear_git_config() {
    # Clear local config if in a repo
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git config --local --unset-all user.name 2>/dev/null || true
        git config --local --unset-all user.email 2>/dev/null || true
        git config --local --unset-all core.sshCommand 2>/dev/null || true
    fi
    
    # Clear global config in test environment
    git config --global --unset-all user.name 2>/dev/null || true
    git config --global --unset-all user.email 2>/dev/null || true
    git config --global --unset-all core.sshCommand 2>/dev/null || true
}

# Set up git test environment with clean state
setup_git_test_environment() {
    # Ensure we start with clean git config
    clear_git_config
    
    # Set minimal global config to avoid git warnings
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    git config --global init.defaultBranch "main"
}

# Clean up git test environment
cleanup_git_test_environment() {
    clear_git_config
}

# Create a complex git scenario with multiple repositories
setup_complex_git_scenario() {
    # Create main working repository
    export TEST_MAIN_REPO=$(create_test_git_repo "main_repo")
    
    # Create repository with existing SSH config
    export TEST_SSH_REPO=$(create_git_repo_with_ssh "ssh_repo" "$TEST_ED25519_KEY")
    
    # Create repository with specific user config
    export TEST_USER_REPO=$(create_git_repo_with_config "user_repo" "Existing User" "existing@example.com")
    
    # Create bare repository for remote testing
    export TEST_BARE_REPO=$(create_bare_git_repo "remote_repo")
}

# Clean up complex git scenario
cleanup_complex_git_scenario() {
    unset TEST_MAIN_REPO TEST_SSH_REPO TEST_USER_REPO TEST_BARE_REPO
}