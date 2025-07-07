#!/usr/bin/env bats

# Service tests for validate_gpg_key

load '../helpers/test_helper'

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "validate_gpg_key accepts empty string" {
    run validate_gpg_key ""
    assert_success
}

@test "validate_gpg_key fails when gpg binary missing" {
    # Temporarily shadow gpg in PATH
    mkdir -p "$TEST_HOME/bin"
    export OLD_PATH="$PATH"
    export PATH="$TEST_HOME/bin:$PATH"
    mv "$(command -v gpg)" "$TEST_HOME/bin/real_gpg" 2>/dev/null || true
    # Ensure gpg not found
    run validate_gpg_key "ABC123"
    assert_failure
    export PATH="$OLD_PATH"
}

@test "validate_gpg_key fails for unknown key id" {
    if ! command -v gpg >/dev/null 2>&1; then
      skip "gpg not available"
    fi
    run validate_gpg_key "NONEXISTENTKEYID"
    assert_failure
} 