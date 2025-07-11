#\!/bin/bash

# Setup test environment
export TEST_HOME="./test_env_$$"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
export GH_PROJECT_CONFIG="$TEST_HOME/.gh-project-accounts"
export GH_USERS_CONFIG="$TEST_HOME/.gh-users"
export GH_USER_PROFILES="$TEST_HOME/.gh-user-profiles"

# Create project assignment
echo "test-repo=testuser" > "$GH_PROJECT_CONFIG"

# Source the script
source ./gh-switcher.sh

# Create a test git repo
mkdir -p "$TEST_HOME/test-repo"
cd "$TEST_HOME/test-repo"
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Mock gh command
gh() {
    if [[ "$1 $2 $3 $4" == "api user -q .login" ]]; then
        echo "testuser"
        return 0
    fi
    return 1
}

# Run guard_test
echo "Running guard_test..."
guard_test
echo "Exit code: $?"

# Cleanup
cd ../..
rm -rf "$TEST_HOME"
