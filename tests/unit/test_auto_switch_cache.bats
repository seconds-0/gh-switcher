#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_environment
    ORIGINAL_PATH="$PATH"
    AUTO_SWITCH_CACHE_DIR="$TEST_HOME/cache"
}

teardown() {
    PATH="$ORIGINAL_PATH"
    cleanup_test_environment
}

create_stub_bin_dir() {
    local dir="$BATS_TEST_TMPDIR/fake_bin_$BATS_TEST_NAME"
    mkdir -p "$dir"
    echo "$dir"
}

@test "auto-switch cache uses sha256sum when available" {
    local fake_bin
    fake_bin=$(create_stub_bin_dir)

    cat > "$fake_bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
printf '%s' "$input" > "${BATS_TEST_TMPDIR}/sha256sum_called"
crc=$(printf '%s' "$input" | cksum | awk '{print $1}')
printf '%08x%08x  -\n' "$((10#$crc % 0x100000000))" "${#input}"
EOF
    chmod +x "$fake_bin/sha256sum"

    PATH="$fake_bin:$ORIGINAL_PATH"

    local path="/tmp/test path"
    local cache_path
    cache_path=$(auto_switch_cache_file "$path")

    [[ -f "${BATS_TEST_TMPDIR}/sha256sum_called" ]]
    local expected_hash
    expected_hash=$(auto_switch_hash "$path")
    [[ "$cache_path" == "$AUTO_SWITCH_CACHE_DIR/path-$expected_hash" ]]
}

@test "auto-switch cache falls back to shasum when sha256sum fails" {
    local fake_bin
    fake_bin=$(create_stub_bin_dir)

    cat > "$fake_bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$@" > "${BATS_TEST_TMPDIR}/sha256sum_invoked"
exit 1
EOF
    chmod +x "$fake_bin/sha256sum"

    cat > "$fake_bin/shasum" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" != "-a" || "$2" != "256" ]]; then
  exit 2
fi
shift 2
input=$(cat)
printf '%s' "$input" > "${BATS_TEST_TMPDIR}/shasum_called"
crc=$(printf '%s' "$input" | cksum | awk '{print $1}')
printf '%08x%08x  -\n' "$((10#$crc % 0x100000000))" "${#input}"
EOF
    chmod +x "$fake_bin/shasum"

    PATH="$fake_bin:$ORIGINAL_PATH"

    local path="/tmp/fallback test"
    local cache_path
    cache_path=$(auto_switch_cache_file "$path")

    [[ -f "${BATS_TEST_TMPDIR}/sha256sum_invoked" ]]
    [[ -f "${BATS_TEST_TMPDIR}/shasum_called" ]]

    local expected_hash
    expected_hash=$(auto_switch_hash "$path")
    [[ "$cache_path" == "$AUTO_SWITCH_CACHE_DIR/path-$expected_hash" ]]
}

@test "auto-switch cache uses internal fallback when external tools unavailable" {
    local fake_bin
    fake_bin=$(create_stub_bin_dir)

    for cmd in sha256sum shasum openssl python3 python; do
        cat > "$fake_bin/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
        chmod +x "$fake_bin/$cmd"
    done

    PATH="$fake_bin:$ORIGINAL_PATH"

    local path="/tmp/internal fallback"
    local cache_hash
    cache_hash=$(auto_switch_hash "$path")
    local fallback_hash
    fallback_hash=$(auto_switch_hash_fallback "$path")

    [[ "$cache_hash" == "$fallback_hash" ]]
    [[ "$cache_hash" =~ ^[0-9a-f]{16}$ ]]
}
