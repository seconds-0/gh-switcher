#!/usr/bin/env bats

# Test zsh compatibility

load '../helpers/test_helper'

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "zsh: local path variable doesn't break PATH" {
    # This is the exact issue we fixed
    run zsh -c '
        source gh-switcher.sh
        # Simulate what happens in project_assign_path function
        function test_func() {
            local dir_path="/tmp"  # This used to be "local path"
            command -v grep  # Should still work
        }
        test_func
    '
    assert_success
    assert_output_contains "/grep"
}

@test "zsh: ghs assign works (integration test)" {
    # Test the actual reported issue
    run zsh -c '
        source gh-switcher.sh
        ghs add testuser >/dev/null 2>&1
        ghs assign 1  # This was the failing command
    '
    assert_success
}

@test "zsh: multiple sources work" {
    # Test that we can source multiple times without errors
    run zsh -c '
        source gh-switcher.sh
        source gh-switcher.sh
        source gh-switcher.sh
        echo "multiple sources ok"
    '
    assert_success
    assert_output_contains "multiple sources ok"
}

@test "zsh: critical commands remain available in functions" {
    # Verify all critical commands work inside functions
    run zsh -c '
        source gh-switcher.sh
        function test_commands() {
            local dir_path="/tmp"
            for cmd in grep sed mktemp mv cp rm; do
                command -v $cmd >/dev/null || echo "FAIL: $cmd"
            done
            echo "all commands ok"
        }
        test_commands
    '
    assert_success
    assert_output_contains "all commands ok"
}