# Windows Test Fixes Plan

## Test Failure Analysis

### Category 1: SSH Permission Failures (9 tests)
These all fail because `stat` returns different values on NTFS and we check for exact "600":
- `not ok 83 add_user fixes SSH key permissions`
- `not ok 101 validate_ssh_key accepts valid ed25519 key`
- `not ok 102 validate_ssh_key accepts valid RSA key`
- `not ok 105 validate_ssh_key fixes permissions`
- `not ok 118 SSH key permissions are fixed automatically`
- `not ok 119 SSH functions handle tilde in paths`
- `not ok 165 ghs edit expands tilde in paths`
- `not ok 10 e2e: ssh auth flow` (likely same issue)
- `not ok 58 complete workflow with multiple hosts` (includes SSH steps)

### Category 2: Performance Failures (3 tests)
These fail because Git Bash is slower than the hardcoded timeouts:
- `not ok 54 guard hook executes within performance requirements` (expects < 1s)
- `not ok 172 ghs show completes within reasonable time` (expects < 300ms)
- `not ok 173 ghs edit completes within reasonable time` (expects < 350ms)

### Category 3: Missing Zsh (4 tests)
These fail because zsh isn't installed on Windows CI:
- `not ok 203-206 zsh tests` (all fail with "zsh: command not found")

### Category 4: Display/Output Issue (1 test)
- `not ok 154 ghs show displays profile information` (expects "✅" but might be encoding issue)

## Root Cause Analysis

### 1. SSH Permissions Root Cause
```bash
# Current code in validate_ssh_key():
perms=$(stat -f %Lp "$ssh_key" 2>/dev/null || stat -c %a "$ssh_key" 2>/dev/null)
if [[ "$perms" != "600" ]]; then
    # FAILS on Windows because stat returns different values
```

On Windows/NTFS:
- `chmod 600` doesn't actually change Windows ACLs
- `stat` might return "644" or "755" or other values
- Git Bash's SSH ignores these permissions anyway

### 2. Performance Root Cause
```bash
# Tests have hardcoded timeouts:
[[ $execution_time -lt 1 ]]      # 1 second
[[ "$duration" -lt 300 ]]        # 300ms
[[ "$duration" -lt 350 ]]        # 350ms
```

Git Bash has overhead from POSIX emulation layer.

## Implementation Plan

### Fix 1: Make SSH Permission Check Platform-Aware
```bash
# In gh-switcher.sh, modify validate_ssh_key function:

validate_ssh_key() {
    local ssh_key="$1"
    local fix_perms="${2:-true}"
    
    # ... existing validation ...
    
    # Check permissions
    local perms
    perms=$(stat -f %Lp "$ssh_key" 2>/dev/null || stat -c %a "$ssh_key" 2>/dev/null)
    perms=$(echo "$perms" | grep -E '^[0-7]+$' | head -1)
    
    if [[ "$perms" != "600" ]]; then
        if [[ "$OSTYPE" == "msys" ]]; then
            # On Windows/Git Bash, permissions can't be properly set on NTFS
            # But Git Bash's SSH doesn't check permissions anyway
            if [[ "$fix_perms" == true ]]; then
                # Try chmod anyway (sets read-only bit at least)
                chmod 600 "$ssh_key" 2>/dev/null || true
                echo "ℹ️  Note: SSH key permissions are limited on Windows NTFS" >&2
                echo "   Git Bash SSH will work correctly anyway" >&2
            fi
            return 0  # Success on Windows even if perms aren't 600
        else
            # On Unix, this is a real problem
            if [[ "$fix_perms" == true ]]; then
                echo "🔧 Fixing SSH key permissions..."
                chmod 600 "$ssh_key"
                return 0
            else
                echo "⚠️  SSH key has incorrect permissions: $perms (should be 600)" >&2
                echo "   SSH requires private keys to be readable only by you." >&2
                echo "   Fix with: chmod 600 '$ssh_key'" >&2
                return 1
            fi
        fi
    fi
    
    return 0
}
```

### Fix 2: Add Performance Multiplier
```bash
# At the top of gh-switcher.sh, add:
GHS_PERF_MULTIPLIER=1
[[ "$OSTYPE" == "msys" ]] && GHS_PERF_MULTIPLIER=2

# Then in any performance-sensitive code, use:
# timeout=$((base_timeout * GHS_PERF_MULTIPLIER))
```

### Fix 3: Update Test Helpers for Platform-Aware Timeouts
```bash
# In tests/helpers/test_helper.bash, add:
get_timeout_ms() {
    local base_timeout=$1
    if [[ "$OSTYPE" == "msys" ]]; then
        echo $((base_timeout * 2))
    else
        echo $base_timeout
    fi
}

# Then in tests:
local timeout=$(get_timeout_ms 300)
[[ "$duration" -lt "$timeout" ]]
```

### Fix 4: Skip Zsh Tests on Windows
```bash
# In tests/e2e/test_zsh_specific.bats setup():
setup() {
    [[ "$OSTYPE" == "msys" ]] && skip "Zsh not available on Windows CI"
    # ... rest of setup
}
```

### Fix 5: Handle Check Mark Display
```bash
# In show_ssh_key_status() or similar:
get_status_symbol() {
    if [[ "$1" == "success" ]]; then
        # Use ASCII on Windows to avoid encoding issues
        [[ "$OSTYPE" == "msys" ]] && echo "[OK]" || echo "✅"
    else
        [[ "$OSTYPE" == "msys" ]] && echo "[X]" || echo "❌"
    fi
}
```

## Implementation Steps

1. **Update validate_ssh_key()** to handle Windows permissions correctly
2. **Add performance multiplier** global variable
3. **Update test helper** with platform-aware timeout function
4. **Update performance tests** to use dynamic timeouts
5. **Add setup check** for zsh tests to skip on Windows
6. **Test locally** with a Windows VM or WSL

## Success Criteria

- All tests pass on Windows (or are explicitly skipped)
- No "test theatre" - tests still validate real functionality
- Code changes are minimal and platform-specific
- SSH operations actually work on Windows (not just pass tests)

## Estimated Time

- 4-6 hours of implementation
- 2 hours of testing
- Total: 1 day

## Alternative: Document as Beta

If we don't want to spend a day fixing these, we could:
1. Skip the failing tests on Windows
2. Document Git Bash support as "Beta"
3. Let community report real issues

But fixing it properly is the right approach.