#\!/bin/bash

# Source test helpers
source ../helpers/test_helper.bash
source ../helpers/guard_helper.bash

# Setup environment
setup_guard_test_environment
setup_mock_gh_user "testuser"
setup_test_project_assignment "test-repo" "testuser"

echo "=== Environment Variables ==="
echo "GH_PROJECT_CONFIG: $GH_PROJECT_CONFIG"
echo "GH_USERS_CONFIG: $GH_USERS_CONFIG"
echo "GH_USER_PROFILES: $GH_USER_PROFILES"
echo "TEST_GIT_REPO: $TEST_GIT_REPO"

echo -e "\n=== File Contents ==="
echo "Project config:"
cat "$GH_PROJECT_CONFIG" 2>/dev/null || echo "FILE NOT FOUND"

echo -e "\nUsers config:"
cat "$GH_USERS_CONFIG" 2>/dev/null || echo "FILE NOT FOUND"

echo -e "\nProfiles:"
cat "$GH_USER_PROFILES" 2>/dev/null || echo "FILE NOT FOUND"

echo -e "\n=== Git repo check ==="
cd "$TEST_GIT_REPO"
echo "PWD: $(pwd)"
echo "git rev-parse --show-toplevel: $(git rev-parse --show-toplevel 2>&1)"

# Now run the actual command
echo -e "\n=== Running guard test ==="
bash "$BATS_TEST_DIRNAME/../../gh-switcher.sh" guard test

# Cleanup
cleanup_guard_test_environment
