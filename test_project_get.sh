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
echo "Contents of project config:"
cat "$GH_PROJECT_CONFIG"

# Source the script
source ./gh-switcher.sh

# Test project_get_user
echo "Testing project_get_user with 'test-repo':"
result=$(project_get_user "test-repo")
echo "Result: '$result', exit code: $?"

# Cleanup
rm -rf "$TEST_HOME"
