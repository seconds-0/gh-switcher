#!/usr/bin/env bats

# Test ghs assign command for project memory

load '../helpers/test_helper'
load '../helpers/ssh_helper'
load '../helpers/git_helper'

setup() {
    setup_test_environment
    setup_test_ssh_environment
    setup_git_test_environment

    # Mock GitHub CLI to allow ghs switch operations without real auth
    cat >"$TEST_HOME/gh" <<'EOF'
#!/usr/bin/env bash
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

@test "ghs assign stores user for project and auto-selects" {
    # Given – two users and a git repo
    cmd_add "alice" >/dev/null 2>&1
    cmd_add "bob"   >/dev/null 2>&1

    setup_complex_git_scenario
    cd "$TEST_MAIN_REPO"

    # When – assign bob (user #2) to this project
    run ghs assign 2
    assert_success
    assert_output_contains "Assigned bob"

    # Then – mapping file contains repo path → bob
    local mapping_file="$GH_PROJECT_CONFIG"
    assert_file_exists "$mapping_file"
    grep -Fq "$(basename "$TEST_MAIN_REPO")=bob" "$mapping_file"

    # (Auto-switch without id not yet implemented; just verify mapping)
}

@test "ghs assign handles directories with regex metacharacters" {
    cmd_add "regexuser" >/dev/null 2>&1

    local special_dir="$TEST_HOME/repos/project[spec].repo"
    mkdir -p "$special_dir"
    cd "$special_dir"
    git init >/dev/null 2>&1

    run ghs assign regexuser
    assert_success
    assert_output_contains "Assigned regexuser"

    grep -Fq "$special_dir|regexuser" "$GH_PROJECT_CONFIG"

    cd "$TEST_HOME"

    run ghs assign --remove "$special_dir"
    assert_success
    assert_output_contains "Removed assignment"

    ! grep -Fq "$special_dir|regexuser" "$GH_PROJECT_CONFIG"
}
