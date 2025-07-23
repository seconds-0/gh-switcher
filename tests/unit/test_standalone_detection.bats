#!/usr/bin/env bats

load '../helpers/test_helper'

# Test data setup
setup() {
    export TEST_DIR="$BATS_TEST_TMPDIR/standalone-test"
    mkdir -p "$TEST_DIR"
    
    # Find the gh-switcher.sh script
    local script_path
    if [[ -n "$BATS_TEST_DIRNAME" ]]; then
        script_path="$BATS_TEST_DIRNAME/../../gh-switcher.sh"
    else
        script_path="./gh-switcher.sh"
    fi
    
    cp "$script_path" "$TEST_DIR/gh-switcher.sh"
    chmod +x "$TEST_DIR/gh-switcher.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "standalone: bash detects direct execution" {
    run bash -c "$TEST_DIR/gh-switcher.sh help 2>&1"
    assert_success
    assert_output_not_contains "auto-switch"
    assert_output_not_contains "fish-setup"
}

@test "standalone: bash detects sourced execution" {
    run bash -c "source $TEST_DIR/gh-switcher.sh && ghs help 2>&1"
    assert_success
    assert_output_contains "auto-switch"
    assert_output_contains "fish-setup"
}

@test "standalone: zsh detects direct execution" {
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh not available"
    fi
    
    run zsh -c "$TEST_DIR/gh-switcher.sh help 2>&1"
    assert_success
    assert_output_not_contains "auto-switch"
    assert_output_not_contains "fish-setup"
}

@test "standalone: zsh detects sourced execution" {
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh not available"
    fi
    
    run zsh -c "source $TEST_DIR/gh-switcher.sh && ghs help 2>&1"
    assert_success
    assert_output_contains "auto-switch"
    assert_output_contains "fish-setup"
}

@test "standalone: works with symlinks" {
    ln -s "$TEST_DIR/gh-switcher.sh" "$TEST_DIR/ghs-link"
    run bash -c "$TEST_DIR/ghs-link help 2>&1"
    assert_success
    assert_output_not_contains "auto-switch"
}

@test "standalone: works with renamed script" {
    mv "$TEST_DIR/gh-switcher.sh" "$TEST_DIR/ghs"
    run bash -c "$TEST_DIR/ghs help 2>&1"
    assert_success
    assert_output_not_contains "auto-switch"
}

@test "standalone: auto-switch shows error when executed directly" {
    run bash -c "$TEST_DIR/gh-switcher.sh auto-switch enable"
    assert_failure
    assert_output_contains "Auto-switch requires shell integration"
    assert_output_contains "https://github.com/seconds-0/gh-switcher#manual-installation"
}

@test "standalone: fish-setup shows error when executed directly" {
    run bash -c "$TEST_DIR/gh-switcher.sh fish-setup"
    assert_failure
    assert_output_contains "Fish setup requires shell integration"
}

@test "standalone: detection function works correctly when sourced" {
    # Test is_standalone directly when sourced
    run bash -c "source $TEST_DIR/gh-switcher.sh && is_standalone && echo 'standalone' || echo 'sourced'"
    assert_success
    assert_output_contains "sourced"
}

@test "standalone: detection function works correctly when executed" {
    # Create a test script that calls is_standalone
    cat > "$TEST_DIR/test-detection.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/gh-switcher.sh"
if is_standalone; then
    echo "standalone"
else
    echo "sourced"
fi
EOF
    chmod +x "$TEST_DIR/test-detection.sh"
    
    run bash -c "$TEST_DIR/test-detection.sh"
    assert_success
    assert_output_contains "sourced"  # Because we're sourcing it within the test script
}

@test "standalone: help shows auto-switch section only when sourced" {
    # When sourced, should show AUTO-SWITCHING section
    run bash -c "source $TEST_DIR/gh-switcher.sh && ghs help 2>&1"
    assert_success
    assert_output_contains "AUTO-SWITCHING:"
    
    # When executed, should not show AUTO-SWITCHING section
    run bash -c "$TEST_DIR/gh-switcher.sh help 2>&1"
    assert_success
    assert_output_not_contains "AUTO-SWITCHING:"
}