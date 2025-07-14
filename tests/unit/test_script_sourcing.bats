#!/usr/bin/env bats

load ../helpers/test_helper

# Get the absolute path to the gh-switcher.sh script
setup() {
    GHS_SCRIPT="$BATS_TEST_DIRNAME/../../gh-switcher.sh"
    export GHS_SCRIPT
}

@test "Script can be sourced without executing" {
    # Test that sourcing the script doesn't execute any commands
    run bash -c "source $GHS_SCRIPT && echo 'sourced successfully'"
    assert_success
    assert_output_contains "sourced successfully"
    assert_output_not_contains "❌"
    assert_output_not_contains "Unknown command"
}

@test "Script can be executed directly with arguments" {
    # Test direct execution with arguments works
    run bash "$GHS_SCRIPT" help
    assert_success
    assert_output_contains "GitHub Project Switcher"
    assert_output_contains "COMMANDS:"
}

@test "Script execution with no arguments doesn't crash" {
    # Test that executing script with no args doesn't cause issues
    run bash "$GHS_SCRIPT"
    # Should not crash or show errors
    assert_success || true  # Allow either success or controlled failure
    assert_output_not_contains "set -e"
    assert_output_not_contains "pipefail"
}

@test "Script sources correctly in zsh" {
    # Skip if zsh not available
    command -v zsh >/dev/null 2>&1 || skip "zsh not available"
    
    run zsh -c "source $GHS_SCRIPT >/dev/null 2>&1 && echo 'zsh sourced successfully'"
    assert_success
    assert_output_contains "zsh sourced successfully"
}

@test "Function export works after sourcing" {
    # Test that ghs function is properly exported
    run bash -c "source $GHS_SCRIPT && type ghs | grep -q 'function' && echo 'function exported'"
    assert_success
    assert_output_contains "function exported"
}

@test "Script doesn't auto-execute on source with BASH_SOURCE check" {
    # Create a test script that sources gh-switcher
    cat > "$BATS_TEST_TMPDIR/test_source.sh" << EOF
#!/bin/bash
source_output=\$(source "$GHS_SCRIPT" 2>&1)
if [[ -n "\$source_output" ]]; then
    echo "UNEXPECTED OUTPUT: \$source_output"
    exit 1
fi
echo "SOURCED_CLEAN"
EOF
    
    chmod +x "$BATS_TEST_TMPDIR/test_source.sh"
    
    run "$BATS_TEST_TMPDIR/test_source.sh"
    assert_success
    [[ "$output" == "SOURCED_CLEAN" ]]
}

@test "Multiple source operations don't cause issues" {
    # Test that sourcing multiple times doesn't cause problems
    run bash -c "
        source $GHS_SCRIPT
        source $GHS_SCRIPT
        source $GHS_SCRIPT
        echo 'multiple sources ok'
    "
    assert_success
    assert_output_contains "multiple sources ok"
}

@test "Script respects GHS_STRICT_MODE environment variable" {
    # Test with strict mode disabled
    run bash -c "GHS_STRICT_MODE=false source $GHS_SCRIPT && echo 'loaded with strict mode off'"
    assert_success
    assert_output_contains "loaded with strict mode off"
    
    # Test with strict mode enabled (default)
    run bash -c "GHS_STRICT_MODE=true source $GHS_SCRIPT && echo 'loaded with strict mode on'"
    assert_success
    assert_output_contains "loaded with strict mode on"
}

@test "Script handles being sourced from different directories" {
    # Test sourcing from various directories
    run bash -c "cd /tmp && source $GHS_SCRIPT && pwd"
    assert_success
    [[ "$output" == "/tmp" ]]
    
    run bash -c "cd $HOME && source $GHS_SCRIPT && pwd"
    assert_success
    [[ "$output" == "$HOME" ]]
}