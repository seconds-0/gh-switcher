#!/usr/bin/env bats

# Test ghs switch command end-to-end

load '../helpers/test_helper'
load '../helpers/ssh_helper'
load '../helpers/git_helper'

setup() {
    setup_test_environment
    setup_test_ssh_environment
    setup_git_test_environment

    # Create a mock `gh` CLI to avoid real network/auth requirements
    cat >"$TEST_HOME/gh" <<'EOF'
#!/usr/bin/env bash
# Minimal stub for GitHub CLI used in tests
if [[ "$1" == "auth" && "$2" == "switch" && "$3" == "--user" ]]; then
  echo "Switched to $4"
  exit 0
fi
echo "Mock gh: unsupported command $*" >&2
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
}

teardown() {
    cleanup_test_ssh_environment
    cleanup_git_test_environment
    cleanup_test_environment
}

@test "ghs switch changes git config to selected user" {
    # Given – two users
    cmd_add "alice" >/dev/null 2>&1
    cmd_add "bob"   >/dev/null 2>&1

    setup_complex_git_scenario
    cd "$TEST_MAIN_REPO"

    # When – switch to user #2 (bob)
    run ghs switch 2

    # Then – command succeeds and local git config reflects bob
    assert_success
    assert_output_contains "Switched to bob (#2)"
    assert_git_local_config "user.name" "bob"
    assert_git_local_config "user.email" "bob@users.noreply.github.com"

    # When – switch back to user #1 (alice)
    run ghs switch 1

    # Then – git config now reflects alice
    assert_success
    assert_git_local_config "user.name" "alice"
    assert_git_local_config "user.email" "alice@users.noreply.github.com"
} 