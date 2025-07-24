#\!/bin/bash
# Debug script to test hook behavior with project assignment

# Set up test environment
export TEST_HOME="/Users/alexanderhuth/Code/gh-switcher/test-hook-$$"
export HOME="$TEST_HOME"
export GH_PROJECT_CONFIG="$TEST_HOME/.gh-project-accounts"
export GH_USERS_CONFIG="$TEST_HOME/.gh-users"
export GH_USER_PROFILES="$TEST_HOME/.gh-user-profiles"
mkdir -p "$TEST_HOME"

# Create test git repo
export TEST_GIT_REPO="$TEST_HOME/test-repo"
mkdir -p "$TEST_GIT_REPO"
cd "$TEST_GIT_REPO"
git init >/dev/null 2>&1

# Add a project assignment
echo "test-repo=testuser" > "$GH_PROJECT_CONFIG"

# Run guard install
bash ../../gh-switcher.sh guard install >/dev/null 2>&1

# Now test with limited PATH
echo "=== Testing with limited PATH and project assignment ==="
PATH="/usr/bin:/bin" bash .git/hooks/pre-commit

# Cleanup
cd /
rm -rf "$TEST_HOME"
