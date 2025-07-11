# IMPLEMENTATION-PLAN-DetailedDesignAndRemediation - Complete Design and Implementation Plan

## Task ID
IMPLEMENTATION-PLAN-DetailedDesignAndRemediation

## Executive Summary
This document consolidates the detailed implementation plan for gh-switcher, incorporating:
- Original UX design principles and detailed implementation plan
- Issues identified during implementation
- Remediation steps for data integrity and reliability
- Clear path forward to achieve production-ready quality

## Original Design Principles

### UX Design: User Delight First

#### Core Principles
1. **Speed is a Feature**: <100ms response time for all operations
2. **Clear Communication**: Every message tells the user exactly what happened
3. **Fail Gracefully**: Errors are opportunities to guide, not frustrate
4. **Progressive Disclosure**: Show what matters now, details on demand

#### Visual Language
- ✅ Success (green) - Operation completed
- ⚠️ Warning (yellow) - Attention needed but not blocking
- ❌ Error (red) - Operation failed, action required
- 💡 Tip (light) - Helpful suggestion
- 🔄 Progress - Operation in progress
- 🔐 Security - SSH/Auth related

### Error State Messages

#### Design Principles for Errors
1. **What went wrong** - Clear, specific description
2. **Why it matters** - Impact on the user
3. **How to fix it** - Actionable next steps
4. **Prevention tips** - How to avoid in future

#### Error Message Templates

**Missing Required Input**
```
❌ Missing username
💡 Usage: ghs add <username>
```

**File Permission Issues**
```
⚠️  SSH key has incorrect permissions (644)
🔧 Fixing permissions...
✅ Set permissions to 600
```

**Authentication Failures**
```
❌ SSH key authentication failed
💡 Ensure key is added to GitHub: https://github.com/settings/keys
```

**Data Corruption**
```
⚠️  Profile file may be corrupted
🔧 Attempting recovery...
✅ Recovered 3 valid profiles
💡 1 corrupted entry saved to ~/.gh-user-profiles.corrupt
```

## Detailed Implementation Workplan

### Phase 1: Core Architecture & Data Safety (CRITICAL)

#### 1.1 Profile Format v3 with Robust Parsing
**Goal**: Implement escape-safe profile format that handles all edge cases

**Implementation**:
```bash
# Profile format: username|v3|name|email|ssh_key
# With escaping: pipes become \|

_escape_profile_field() {
    local field="$1"
    echo "${field//|/\\|}"
}

_parse_v3_profile_safe() {
    local line="$1"
    # Manual parsing to handle escapes properly
    # Must validate exactly 5 fields
    # Must check version == "v3"
}
```

**Test Cases**:
- Profiles with pipes in name/email
- Missing fields
- Extra fields
- Binary data
- Unicode characters

#### 1.2 Concurrent Access Protection
**Goal**: Prevent file corruption from simultaneous operations

**Implementation**:
```bash
_with_file_lock() {
    local file="$1"
    local operation="$2"
    
    exec 200>"${file}.lock"
    flock -w 5 -x 200 || return 1
    "$operation"
    exec 200>&-
}
```

**Test Cases**:
- Two processes adding users simultaneously
- Read during write operation
- Lock timeout handling
- Cleanup on abnormal exit

#### 1.3 Transaction Support
**Goal**: Atomic operations with rollback capability

**Implementation**:
```bash
declare -a _TRANSACTION_CLEANUP=()

_transaction_start() {
    _TRANSACTION_CLEANUP=()
}

_transaction_add_rollback() {
    _TRANSACTION_CLEANUP+=("$1")
}

_transaction_commit() {
    _TRANSACTION_CLEANUP=()
}

_transaction_rollback() {
    # Execute rollbacks in reverse order
}
```

**Test Cases**:
- Rollback on each failure point
- Nested transactions
- Cleanup verification

### Phase 2: Input Validation & Security

#### 2.1 GitHub Username Validation
**Rules**:
- 1-39 characters
- Alphanumeric with single hyphens
- Cannot start/end with hyphen
- No consecutive hyphens

**Implementation**:
```bash
_validate_github_username() {
    local username="$1"
    [[ ${#username} -ge 1 && ${#username} -le 39 ]] || return 1
    [[ "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || return 1
    [[ "$username" != *--* ]] || return 1
}
```

#### 2.2 Path Security
**Implementation**:
```bash
_validate_safe_path() {
    local path="$1"
    # No path traversal
    [[ "$path" != *..* ]] || return 1
    # Expand tilde safely
    local expanded="${path/#\~/$HOME}"
    # Verify exists
    [[ -e "$expanded" ]] || return 1
    echo "$expanded"
}
```

### Phase 3: SSH Integration

#### 3.1 SSH Key Management
**Features**:
- Auto-detect SSH keys
- Validate permissions (600)
- Test GitHub authentication
- Apply to git config

**Implementation**:
```bash
ssh_validate_and_fix() {
    local key_path="$1"
    local expanded_path
    expanded_path=$(_validate_safe_path "$key_path") || return 1
    
    # Check permissions
    local perms
    perms=$(stat -f "%Lp" "$expanded_path" 2>/dev/null) || \
    perms=$(stat -c "%a" "$expanded_path" 2>/dev/null) || return 1
    
    if [[ "$perms" != "600" ]]; then
        echo "⚠️  SSH key has incorrect permissions ($perms)" >&2
        echo "🔧 Fixing permissions..." >&2
        chmod 600 "$expanded_path" || return 1
        echo "✅ Set permissions to 600" >&2
    fi
}

ssh_test_github_auth() {
    local key_path="$1"
    ssh -T -o BatchMode=yes -o ConnectTimeout=5 \
        -i "$key_path" git@github.com 2>&1 | \
        grep -q "successfully authenticated"
}
```

### Phase 4: Guard Hooks

#### 4.1 Pre-commit Hook Implementation
**Features**:
- Detect account mismatch
- Clear error messages
- Performance <300ms
- Skip capability

**Hook Content**:
```bash
#!/bin/bash
# gh-switcher pre-commit hook

# Allow skip
[[ -n "$GHS_SKIP_HOOK" ]] && exit 0

# Find ghs
ghs_path=$(command -v ghs) || {
    echo "❌ ghs not found in PATH" >&2
    exit 1
}

# Run validation
if ! "$ghs_path" guard test; then
    echo "" >&2
    echo "💡 To commit anyway: GHS_SKIP_HOOK=1 git commit" >&2
    exit 1
fi
```

#### 4.2 Guard Command Implementation
```bash
cmd_guard() {
    local action="${1:-status}"
    
    case "$action" in
        install)
            guard_install_hook
            ;;
        test)
            guard_validate_account
            ;;
        status)
            guard_show_status
            ;;
        uninstall)
            guard_uninstall_hook
            ;;
        *)
            echo "❌ Unknown guard action: $action" >&2
            return 1
            ;;
    esac
}
```

### Phase 5: Testing Strategy

#### 5.1 Unit Tests
- Individual function testing
- Edge case coverage
- Error path validation

#### 5.2 Integration Tests
- End-to-end workflows
- Multi-user scenarios
- SSH integration

#### 5.3 Guard Hook Reality Tests
```bash
@test "guard hook prevents actual git commit" {
    # Create real git repo
    git init test-repo
    cd test-repo
    
    # Install hook
    ghs guard install
    
    # Create change
    echo "test" > file.txt
    git add file.txt
    
    # Attempt commit with wrong user
    setup_wrong_user
    run git commit -m "test"
    assert_failure
    
    # Verify no commit created
    run git log
    refute_output_contains "test"
}
```

## Current State Issues (From Implementation)

### Critical Issues Found

1. **Profile Parsing Vulnerabilities**
   - No field count validation
   - Pipes in data break parsing
   - No escape mechanism
   - Silent data truncation

2. **No Concurrent Access Protection**
   - File corruption possible
   - Race conditions in updates
   - No atomic operations

3. **Guard Hook Test Deception**
   - Tests don't verify actual git behavior
   - Only test `ghs guard test` command
   - Misleading test names

4. **Input Validation Gaps**
   - Accepts any string as username
   - No email validation
   - Command injection possible

## Remediation Plan

### Priority Order

#### P0 - Data Integrity (Immediate)
1. Implement safe profile parsing with escaping
2. Add file locking for concurrent access
3. Create transaction framework for atomicity
4. Add corruption detection and recovery

#### P1 - Security (Next)
1. Implement input validation for all user inputs
2. Prevent command injection
3. Validate paths for traversal attacks
4. Secure SSH key handling

#### P2 - Testing Honesty (Following)
1. Rewrite guard hook tests to use actual git
2. Test real commit prevention
3. Verify hook can find ghs in practice
4. Add performance benchmarks

#### P3 - User Experience (Final)
1. Implement comprehensive error messages
2. Add progress indicators
3. Provide actionable fix suggestions
4. Maintain <100ms performance

### Implementation Schedule

**Week 1: Data Safety**
- Day 1-2: Profile format with escaping
- Day 3-4: File locking implementation
- Day 5: Transaction support

**Week 2: Security & Validation**
- Day 1-2: Input validation framework
- Day 3-4: Path security and SSH fixes
- Day 5: Security testing

**Week 3: Testing & Polish**
- Day 1-2: Rewrite guard hook tests
- Day 3-4: Performance optimization
- Day 5: Documentation and release prep

## Success Criteria

### Functional Requirements
- [ ] All profile operations handle special characters
- [ ] Concurrent operations never corrupt files
- [ ] All operations atomic (succeed or rollback)
- [ ] Input validation prevents all injection attacks
- [ ] Guard hooks actually prevent wrong commits
- [ ] SSH keys managed automatically and safely

### Performance Requirements
- [ ] All commands complete in <100ms
- [ ] Guard hooks execute in <300ms
- [ ] File locking adds <10ms overhead
- [ ] Startup time <50ms

### Quality Requirements
- [ ] 100% test coverage of critical paths
- [ ] All functions <50 lines
- [ ] Zero test deception or workarounds
- [ ] Clear error messages with fixes
- [ ] No data loss scenarios possible

### User Experience Requirements
- [ ] Every error includes how to fix it
- [ ] Progress shown for long operations
- [ ] Consistent visual language (✅⚠️❌💡)
- [ ] Helpful tips guide users to success

## Risk Mitigation

### Technical Risks
1. **File Locking Portability**
   - Test on Linux, macOS, WSL
   - Fallback to directory locks if needed

2. **Performance Impact**
   - Benchmark each change
   - Profile hot paths
   - Optimize critical sections

3. **Migration Complexity**
   - Keep v2 format compatibility
   - Automatic migration on first use
   - Backup before migration

### Process Risks
1. **Scope Creep**
   - Stick to defined phases
   - Defer nice-to-haves
   - Focus on core safety first

2. **Testing Complexity**
   - Start with critical paths
   - Add tests incrementally
   - Use real scenarios

## Conclusion

This plan addresses all issues identified during implementation while maintaining the original vision of a fast, safe, and delightful GitHub account switcher. By following this plan systematically, we will achieve:

1. **Data Safety**: No corruption or loss possible
2. **Security**: Protected against malicious input
3. **Reliability**: Predictable behavior in all scenarios
4. **Performance**: Sub-100ms operations
5. **User Delight**: Clear, helpful, actionable feedback

The key is to implement in priority order: safety first, then security, then testing honesty, and finally polish. Each phase builds on the previous, creating a solid foundation for a production-ready tool.

## Next Steps

1. Review and approve this plan
2. Create feature branch for remediation
3. Implement Phase 1 (Data Safety) completely
4. Validate with comprehensive tests
5. Continue through remaining phases
6. Release when all success criteria met

Remember: No shortcuts. No workarounds. Do it right.