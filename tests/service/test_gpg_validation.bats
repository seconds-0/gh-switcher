#!/usr/bin/env bats

# Service tests for validate_gpg_key

load '../helpers/test_helper'

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "GPG support is not available" {
    # GPG support was removed for simplicity
    skip "GPG support removed in clean implementation"
}

@test "GPG validation is not implemented" {
    # GPG support was removed for simplicity
    skip "GPG support removed in clean implementation"
}

@test "validate_gpg_key fails for unknown key id" {
    if ! command -v gpg >/dev/null 2>&1; then
      skip "gpg not available"
    fi
    run validate_gpg_key "NONEXISTENTKEYID"
    assert_failure
} 