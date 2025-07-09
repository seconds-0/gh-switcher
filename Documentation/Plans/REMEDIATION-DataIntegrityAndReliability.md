# REMEDIATION-DataIntegrityAndReliability - Fix Critical Data Safety and Reliability Issues

## Task ID
REMEDIATION-DataIntegrityAndReliability

## Problem Statement
Our current implementation achieved 100% test pass rate but took shortcuts that compromise data integrity and reliability. We have profile parsing vulnerabilities, no concurrent access protection, missing error recovery, and guard hook tests that don't actually test hook execution. These issues violate our core principle of "data safety first" and create risk of user data loss or corruption.

## Current State Analysis

### 1. Profile Parsing Vulnerabilities
**Current Implementation (lines 186-195):**
```bash
_parse_v3_profile() {
    local line="$1"
    local username name email ssh_key version
    
    IFS='|' read -r username version name email ssh_key <<< "$line"
    
    [[ "$version" == "v3" ]] || return 1
    
    echo "$username:$name:$email:$ssh_key"
}
```

**Problems:**
- No validation of field count (accepts "user|v3" as valid)
- Pipe characters in data break parsing
- No escape mechanism for delimiter
- Silent data truncation if fields missing

### 2. No Concurrent Access Protection
**Current Implementation:**
```bash
# Direct file writes without locking
echo "$data" >> "$GH_USERS_FILE"
mv "$temp_file" "$profiles_file"
```

**Problems:**
- Two `ghs` processes can corrupt files
- No atomic read-modify-write operations
- Race conditions in profile updates
- Project assignment file has same issue

### 3. Missing Error Recovery
**Current Implementation:**
```bash
# No cleanup on failure
temp_file=$(mktemp) || return 1
echo "$content" > "$temp_file"
mv "$temp_file" "$target"  # If this fails, temp file remains
```

**Problems:**
- Temp files leak on errors
- No rollback mechanism
- Partial writes leave inconsistent state
- No recovery from corrupted files

### 4. Input Validation Gaps
**Current Implementation:**
```bash
cmd_add() {
    local username="$1"
    [[ -z "$username" ]] && { echo "❌ Usage: ghs add <username>" >&2; return 1; }
    # No validation of username format
}
```

**Problems:**
- Accepts any string as username (spaces, special chars)
- No email validation
- No SSH key path validation beyond existence
- Command injection possible through crafted input

### 5. Guard Hook Test Deception
**Current Implementation (test_guard_hook_real.bats):**
```bash
@test "guard hook actually prevents commit with wrong account" {
    # ...
    run_guard_command "test"
    assert_failure
    # Note: We've verified the hook is installed and guard test fails.
    # In a real environment, this would prevent the commit.
}
```

**Problems:**
- Never actually tests git commit prevention
- Tests `ghs guard test` instead of hook execution
- Misleading test names and comments
- No verification hook can find `ghs` in practice

### 6. Fragile SSH Key Handling
**Current Implementation:**
```bash
validate_ssh_key() {
    local key_path="$1"
    [[ -f "$key_path" ]] || [[ -f "${key_path/#\~/$HOME}" ]] || return 1
    # Check permissions
    local expanded_path="${key_path/#\~/$HOME}"
    local perms
    perms=$(stat -f "%Lp" "$expanded_path" 2>/dev/null) || perms=$(stat -c "%a" "$expanded_path" 2>/dev/null)
}
```

**Problems:**
- Platform-specific stat commands fragile
- No handling of symlinks
- No validation of key format
- Permission fix might fail silently

## Proposed Solution

### Design Principles
1. **Fail Safe**: Corrupted data should never cause data loss
2. **Atomic Operations**: All changes complete or rollback entirely
3. **Defensive Parsing**: Assume all input is malicious
4. **Honest Testing**: Tests must verify actual behavior
5. **Clear Errors**: Users must understand what went wrong

### Technical Approach
1. Implement proper file locking with flock
2. Add escaping mechanism for profile data
3. Create transaction wrapper for multi-step operations
4. Validate all inputs against defined rules
5. Rewrite guard hook tests to verify actual git behavior
6. Add corruption detection and recovery

## Implementation Details

### Phase 1: Profile Format Hardening (Critical)
Implement robust parsing with escaping and validation.

**New Profile Format:**
- Keep pipe delimiter but add escaping: `\|` for literal pipes
- Enforce exactly 5 fields for v3
- Add checksum line for corruption detection

**Implementation:**
```bash
# Escape special characters in profile data
_escape_profile_field() {
    local field="$1"
    echo "${field//|/\\|}"
}

# Unescape when reading
_unescape_profile_field() {
    local field="$1"
    echo "${field//\\|/|}"
}

# Validate and parse with field count check
_parse_v3_profile_safe() {
    local line="$1"
    local fields=()
    local escaped_field=""
    local in_escape=0
    
    # Manual parsing to handle escapes
    for (( i=0; i<${#line}; i++ )); do
        local char="${line:i:1}"
        local next_char="${line:i+1:1}"
        
        if [[ "$char" == "\\" ]] && [[ "$next_char" == "|" ]]; then
            escaped_field+="|"
            ((i++))  # Skip next char
        elif [[ "$char" == "|" ]]; then
            fields+=("$escaped_field")
            escaped_field=""
        else
            escaped_field+="$char"
        fi
    done
    fields+=("$escaped_field")  # Don't forget last field
    
    # Validate field count
    [[ ${#fields[@]} -eq 5 ]] || return 1
    [[ "${fields[1]}" == "v3" ]] || return 1
    
    echo "${fields[0]}:${fields[2]}:${fields[3]}:${fields[4]}"
}

# Add file checksum for corruption detection
_write_profiles_with_checksum() {
    local temp_file="$1"
    local content="$2"
    
    echo "$content" > "$temp_file"
    echo "# CHECKSUM: $(sha256sum "$temp_file" | cut -d' ' -f1)" >> "$temp_file"
}
```

### Phase 2: Concurrent Access Protection
Implement file locking for all file operations.

**Implementation:**
```bash
# Acquire exclusive lock with timeout
_lock_file() {
    local file="$1"
    local timeout="${2:-5}"
    
    exec 200>"${file}.lock"
    if ! flock -w "$timeout" -x 200; then
        echo "❌ Could not acquire lock on $file (timeout after ${timeout}s)" >&2
        return 1
    fi
}

# Release lock
_unlock_file() {
    exec 200>&-
}

# Wrap operations in lock
_safe_append_to_file() {
    local file="$1"
    local content="$2"
    
    _lock_file "$file" || return 1
    echo "$content" >> "$file"
    local result=$?
    _unlock_file
    return $result
}

# Atomic read-modify-write
_safe_update_file() {
    local file="$1"
    local update_function="$2"
    
    _lock_file "$file" || return 1
    
    local temp_file
    temp_file=$(mktemp "${file}.XXXXXX") || { _unlock_file; return 1; }
    
    # Read current content and apply update
    if [[ -f "$file" ]]; then
        "$update_function" < "$file" > "$temp_file" || {
            rm -f "$temp_file"
            _unlock_file
            return 1
        }
    fi
    
    # Atomic replace
    mv -f "$temp_file" "$file" || {
        rm -f "$temp_file"
        _unlock_file
        return 1
    }
    
    _unlock_file
    return 0
}
```

### Phase 3: Transaction Support & Error Recovery
Implement rollback capability for multi-step operations.

**Implementation:**
```bash
# Transaction context for rollback
declare -a _TRANSACTION_CLEANUP=()

_transaction_start() {
    _TRANSACTION_CLEANUP=()
}

_transaction_add_rollback() {
    local rollback_cmd="$1"
    _TRANSACTION_CLEANUP+=("$rollback_cmd")
}

_transaction_commit() {
    _TRANSACTION_CLEANUP=()
}

_transaction_rollback() {
    local i
    for (( i=${#_TRANSACTION_CLEANUP[@]}-1; i>=0; i-- )); do
        eval "${_TRANSACTION_CLEANUP[i]}" || true
    done
    _TRANSACTION_CLEANUP=()
}

# Example usage in cmd_add
cmd_add() {
    local username="$1"
    
    # Start transaction
    _transaction_start
    
    # Add user to users file
    if _safe_append_to_file "$GH_USERS_FILE" "$username"; then
        _transaction_add_rollback "_remove_user_from_file '$username'"
    else
        _transaction_rollback
        return 1
    fi
    
    # Add profile
    if ! _add_user_profile "$username" "$name" "$email" "$ssh_key"; then
        _transaction_rollback
        return 1
    fi
    
    # Success - commit transaction
    _transaction_commit
    echo "✅ Added $username"
}

# Cleanup on script exit
trap '_transaction_rollback' EXIT
```

### Phase 4: Input Validation Framework
Implement comprehensive validation for all user inputs.

**Implementation:**
```bash
# GitHub username rules: alphanumeric, single hyphens, not start/end with hyphen
_validate_github_username() {
    local username="$1"
    
    # Length check
    [[ ${#username} -ge 1 ]] && [[ ${#username} -le 39 ]] || {
        echo "❌ Username must be 1-39 characters" >&2
        return 1
    }
    
    # Character and pattern check
    if [[ ! "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        echo "❌ Username must be alphanumeric, may contain single hyphens" >&2
        return 1
    fi
    
    # No double hyphens
    if [[ "$username" == *--* ]]; then
        echo "❌ Username cannot contain consecutive hyphens" >&2
        return 1
    fi
    
    return 0
}

# Email validation (basic)
_validate_email() {
    local email="$1"
    
    # Basic pattern - not comprehensive but catches obvious errors
    if [[ ! "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        echo "❌ Invalid email format" >&2
        return 1
    fi
    
    return 0
}

# Path validation with security checks
_validate_path_input() {
    local path="$1"
    local path_type="${2:-file}"  # file or directory
    
    # No path traversal
    if [[ "$path" == *..* ]]; then
        echo "❌ Path cannot contain .." >&2
        return 1
    fi
    
    # Expand tilde safely
    local expanded_path="${path/#\~/$HOME}"
    
    # Check existence based on type
    if [[ "$path_type" == "file" ]]; then
        [[ -f "$expanded_path" ]] || {
            echo "❌ File not found: $path" >&2
            return 1
        }
    else
        [[ -d "$expanded_path" ]] || {
            echo "❌ Directory not found: $path" >&2
            return 1
        }
    fi
    
    echo "$expanded_path"
}

# Sanitize for safe shell usage
_sanitize_for_shell() {
    local input="$1"
    # Remove any characters that could be problematic
    echo "${input//[^a-zA-Z0-9._-]/}"
}
```

### Phase 5: Fix Guard Hook Tests
Implement tests that actually verify git commit prevention.

**Implementation:**
```bash
# tests/integration/test_guard_hook_execution.bats

@test "guard hook prevents actual git commit with wrong account" {
    # Setup
    setup_mock_gh_user "correctuser"
    setup_test_project_assignment "test-repo" "correctuser"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    assert_success
    
    # Create a change to commit
    echo "test" > test.txt
    git add test.txt
    
    # Switch to wrong user
    setup_mock_gh_user "wronguser"
    
    # Attempt actual commit - should fail
    run git commit -m "Test commit"
    assert_failure
    assert_output_contains "Account mismatch detected"
    
    # Verify no commit was created
    run git log --oneline
    assert_output_contains "Initial commit"
    refute_output_contains "Test commit"
}

@test "guard hook allows actual git commit with correct account" {
    # Setup with correct user
    setup_mock_gh_user "correctuser"
    setup_test_project_assignment "test-repo" "correctuser"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    assert_success
    
    # Set git config
    git config user.name "Correct User"
    git config user.email "correct@example.com"
    
    # Create a change and commit
    echo "test" > test.txt
    git add test.txt
    
    # Actual commit - should succeed
    run git commit -m "Test commit"
    assert_success
    
    # Verify commit was created
    run git log --oneline
    assert_output_contains "Test commit"
}

@test "GHS_SKIP_HOOK bypasses hook for actual commit" {
    # Setup to fail normally
    setup_mock_gh_user "wronguser"
    setup_test_project_assignment "test-repo" "correctuser"
    
    cd "$TEST_GIT_REPO"
    run_guard_command "install"
    assert_success
    
    # Create change
    echo "test" > test.txt
    git add test.txt
    
    # Commit with skip flag - should succeed despite wrong user
    GHS_SKIP_HOOK=1 run git commit -m "Emergency commit"
    assert_success
    
    # Verify commit created
    run git log --oneline
    assert_output_contains "Emergency commit"
}

# Helper to properly set up hook execution environment
setup_guard_test_environment() {
    setup_test_environment
    
    # Create real git repo
    export TEST_GIT_REPO="$TEST_HOME/test-repo"
    mkdir -p "$TEST_GIT_REPO"
    cd "$TEST_GIT_REPO"
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Initial commit so repo is valid
    echo "# Test" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Ensure ghs is available in PATH for hook execution
    export PATH="$(cd "$BATS_TEST_DIRNAME/../.." && pwd):$PATH"
    
    # Make ghs directly executable
    ln -sf "$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh" "$TEST_HOME/ghs"
    chmod +x "$TEST_HOME/ghs"
}
```

### Phase 6: Corruption Detection & Recovery
Add ability to detect and recover from corrupted files.

**Implementation:**
```bash
# Verify file integrity
_verify_profile_integrity() {
    local file="$1"
    
    [[ -f "$file" ]] || return 0  # Missing is ok
    
    # Check for checksum
    local last_line
    last_line=$(tail -n1 "$file" 2>/dev/null)
    
    if [[ "$last_line" =~ ^#[[:space:]]CHECKSUM:[[:space:]]([a-f0-9]{64})$ ]]; then
        local stored_checksum="${BASH_REMATCH[1]}"
        local actual_checksum
        actual_checksum=$(head -n -1 "$file" | sha256sum | cut -d' ' -f1)
        
        if [[ "$stored_checksum" != "$actual_checksum" ]]; then
            echo "⚠️  Profile file may be corrupted" >&2
            return 1
        fi
    fi
    
    # Validate each line can be parsed
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        if ! _parse_v3_profile_safe "$line" >/dev/null 2>&1; then
            echo "⚠️  Invalid profile data at line $line_num" >&2
            return 1
        fi
    done < "$file"
    
    return 0
}

# Attempt recovery from corruption
_recover_corrupted_file() {
    local file="$1"
    local backup_dir="${HOME}/.gh-switcher-backups"
    
    mkdir -p "$backup_dir"
    
    # Save corrupted file
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$file" "$backup_dir/$(basename "$file").corrupted.$timestamp"
    
    # Try to recover valid lines
    local temp_file
    temp_file=$(mktemp) || return 1
    local recovered=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        if _parse_v3_profile_safe "$line" >/dev/null 2>&1; then
            echo "$line" >> "$temp_file"
            ((recovered++))
        fi
    done < "$file"
    
    if [[ $recovered -gt 0 ]]; then
        _write_profiles_with_checksum "$file" "$(cat "$temp_file")"
        rm -f "$temp_file"
        echo "✅ Recovered $recovered valid profiles" >&2
        return 0
    else
        rm -f "$temp_file"
        echo "❌ No valid data could be recovered" >&2
        return 1
    fi
}

# Load profiles with integrity check
load_profiles() {
    if ! _verify_profile_integrity "$GH_PROFILES_FILE"; then
        echo "⚠️  Attempting profile recovery..." >&2
        if ! _recover_corrupted_file "$GH_PROFILES_FILE"; then
            echo "❌ Profile recovery failed. Starting fresh." >&2
            mv "$GH_PROFILES_FILE" "${GH_PROFILES_FILE}.corrupt"
            return 1
        fi
    fi
    
    # Normal loading...
}
```

## Implementation Checklist

### Phase 1: Profile Format Hardening
- [ ] Implement field escaping/unescaping functions
- [ ] Create robust parser with field count validation
- [ ] Add checksum generation for profile files
- [ ] Update all profile write operations to use new format
- [ ] Create migration for existing profiles
- [ ] Test with pipes, newlines, special chars in all fields

### Phase 2: Concurrent Access Protection
- [ ] Implement file locking wrapper functions
- [ ] Add lock timeout handling
- [ ] Update all file operations to use locking
- [ ] Test concurrent operations don't corrupt
- [ ] Add lock cleanup on abnormal exit
- [ ] Document lock file locations

### Phase 3: Transaction Support
- [ ] Implement transaction framework
- [ ] Add rollback commands for each operation
- [ ] Update cmd_add to use transactions
- [ ] Update cmd_remove to use transactions
- [ ] Test rollback on various failure points
- [ ] Add transaction timeout handling

### Phase 4: Input Validation
- [ ] Implement GitHub username validation
- [ ] Add email format validation
- [ ] Create path validation with security checks
- [ ] Add input sanitization functions
- [ ] Update all commands to validate inputs
- [ ] Test with malicious inputs

### Phase 5: Guard Hook Tests
- [ ] Rewrite tests to use actual git commits
- [ ] Test hook execution in various PATH scenarios
- [ ] Verify hook prevents wrong-account commits
- [ ] Test GHS_SKIP_HOOK actually bypasses
- [ ] Add performance tests for hook execution
- [ ] Document test environment setup clearly

### Phase 6: Corruption Recovery
- [ ] Implement integrity verification
- [ ] Add automatic backup before updates
- [ ] Create recovery mechanism
- [ ] Test recovery scenarios
- [ ] Add user notification for recovery
- [ ] Document backup location and format

## Testing Plan

### Unit Tests
1. **Parsing Tests**
   - Valid v3 profiles with all fields
   - Profiles with pipes in data (escaped)
   - Missing fields, extra fields
   - Corrupted data, binary data
   - Empty files, huge files

2. **Validation Tests**  
   - Valid/invalid GitHub usernames
   - Valid/invalid email formats
   - Path traversal attempts
   - Shell injection attempts

3. **Lock Tests**
   - Acquire/release cycles
   - Timeout behavior
   - Concurrent access simulation
   - Lock cleanup on exit

### Integration Tests
1. **Concurrent Operations**
   - Two processes adding users
   - Read during write
   - Multiple profile updates
   - Lock contention handling

2. **Transaction Tests**
   - Successful multi-step operations
   - Rollback on each failure point
   - Nested transaction behavior
   - Cleanup verification

3. **Guard Hook Reality**
   - Actual commit prevention
   - Various git configurations
   - Different shell environments
   - Performance under load

### Manual Tests
1. **Corruption Scenarios**
   - Kill during write
   - Disk full during operation
   - Manual file corruption
   - Recovery verification

2. **Real-world Usage**
   - Multiple terminal sessions
   - Script automation
   - CI/CD environments
   - Different shells/platforms

## Success Criteria

### Functionality
- [ ] All profile operations handle pipes in data correctly
- [ ] Concurrent operations never corrupt files
- [ ] All operations either fully succeed or fully rollback
- [ ] Malicious input cannot break parsing or execute commands
- [ ] Guard hooks actually prevent wrong-account commits
- [ ] Corrupted files are detected and recovered

### Performance
- [ ] File locking adds <10ms overhead
- [ ] Validation adds <5ms overhead  
- [ ] Overall performance stays <100ms
- [ ] Lock timeout is reasonable (5s default)

### Reliability
- [ ] 100% test pass rate maintained
- [ ] No data loss scenarios exist
- [ ] Clear error messages for all failures
- [ ] Graceful degradation on errors
- [ ] No test deception or workarounds

### Code Quality
- [ ] All functions stay <50 lines
- [ ] Clear separation of concerns
- [ ] Consistent error handling
- [ ] Well-documented edge cases
- [ ] No shortcuts or hacks

## Risk Analysis

### High Risk Areas
1. **Data Migration**: Existing users' profiles must convert cleanly
2. **Lock Contention**: Poor implementation could deadlock
3. **Performance**: Locking could slow operations significantly
4. **Compatibility**: File locking behavior varies by platform

### Mitigation Strategies
1. **Backup Before Migration**: Keep .v2 backup files
2. **Lock Timeouts**: Prevent infinite waits
3. **Benchmark Everything**: Measure impact of each change
4. **Platform Testing**: Test on Linux, macOS, various filesystems

## Status
Not Started

## Notes
- This plan addresses all "90% solution" issues identified in the post-mortem
- Each phase builds on the previous - don't skip ahead
- If any phase reveals design flaws, stop and revise plan
- Performance and reliability are equally important
- No workarounds allowed - fix root causes only