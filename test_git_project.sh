#\!/bin/bash

# Setup test environment
export TEST_HOME="./test_env_$$"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
export GH_PROJECT_CONFIG="$TEST_HOME/.gh-project-accounts"

# Create project assignment
echo "test-repo=testuser" > "$GH_PROJECT_CONFIG"

# Create a test git repo
mkdir -p "$TEST_HOME/test-repo"
cd "$TEST_HOME/test-repo"
git init >/dev/null 2>&1

echo "Current directory: $(pwd)"
echo "git rev-parse --show-toplevel: $(git rev-parse --show-toplevel 2>&1)"
echo "basename of that: $(basename "$(git rev-parse --show-toplevel 2>&1)")"

# Cleanup
cd ../..
rm -rf "$TEST_HOME"
