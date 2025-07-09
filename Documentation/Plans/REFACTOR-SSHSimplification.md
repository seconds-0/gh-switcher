# REFACTOR-SSHSimplification - Simplify Overengineered SSH Key Management

## Task ID
REFACTOR-SSHSimplification

## Problem Statement

The current SSH key implementation in gh-switcher violates core project principles and demonstrates severe overengineering:

- **Function size violations**: 58-line `validate_ssh_key()` exceeds 50-line guideline
- **Performance violations**: Network calls in `add_user()` violate <100ms target
- **Complexity violations**: 144 lines of SSH code for simple git config setting
- **Feature creep**: Security theater and edge case handling beyond core use case
- **Philosophy violations**: "Simple over complex" ignored for unnecessary validation

### Current State Analysis
- `validate_ssh_key()`: 58 lines (16% over limit)
- `apply_ssh_config()`: 51 lines (2% over limit) 
- `test_ssh_auth()`: 35 lines of network-dependent complexity
- **Total SSH code**: 144 lines
- **Core functionality needed**: ~25 lines

## Proposed Solution

Replace overengineered SSH implementation with research-validated smart defaults that automate 90%+ of use cases while providing clear manual overrides for edge cases.

### Design Philosophy
- **"Maximally helpful automation with clear manual offramps"**
- **CLI-first**: No interactive prompts, fully scriptable
- **Performance-first**: <100ms command completion, no network dependencies in main workflow
- **Simple over complex**: Minimal viable implementation that just works

## Research Findings

### SSH Key Naming Patterns (Validated via Web Research)
**Priority 1: Exact username match**
- `~/.ssh/id_*[username]*`
- `~/.ssh/[username]*`

**Priority 2: Service patterns**  
- `~/.ssh/id_*github*`
- `~/.ssh/id_*work*`

**Priority 3: Default keys**
- `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`

**Ranking criteria:**
- Ed25519 > RSA (industry preference in 2025)
- Newer > older files
- Correct permissions (600)

### Edge Cases and Solutions
1. **Multiple keys per account**: Auto-pick best, show choice, allow override
2. **Wrong permissions (644→600)**: Auto-fix with notification (safe and expected)
3. **Passphrase-protected keys**: Warn about ssh-agent requirement, don't block
4. **Authentication failures**: Helpful error with GitHub settings link
5. **No SSH keys**: Graceful HTTPS fallback with setup suggestions

## Implementation Details

### Phase 1: Replace Overengineered Functions

#### 1.1: Simplified `validate_ssh_key()` (8 lines vs 58)
```bash
validate_ssh_key() {
    local ssh_key_path="$1"
    [[ -z "$ssh_key_path" ]] && return 0  # Empty is valid
    ssh_key_path="${ssh_key_path/#~/$HOME}"
    
    if [[ ! -f "$ssh_key_path" ]]; then
        echo "❌ SSH key not found: $ssh_key_path"
        return 1
    fi
}
```

**Removed complexity:**
- ❌ Directory traversal protection (security theater)
- ❌ Cross-platform stat permission checking  
- ❌ Automatic permission fixing
- ❌ Private key format validation
- ❌ Complex error messaging

#### 1.2: Simplified `apply_ssh_config()` (12 lines vs 51)
```bash
apply_ssh_config() {
    local ssh_key_path="$1"
    local scope="${2:-local}"
    
    local git_flags="--local"
    [[ "$scope" == "global" ]] && git_flags="--global"
    
    if [[ -z "$ssh_key_path" ]]; then
        git config $git_flags --unset core.sshCommand 2>/dev/null || true
        return 0
    fi
    
    ssh_key_path="${ssh_key_path/#~/$HOME}"
    git config $git_flags core.sshCommand "ssh -i '$ssh_key_path' -o IdentitiesOnly=yes"
}
```

**Removed complexity:**
- ❌ Git availability checking (git commands will fail gracefully)
- ❌ Repository detection (git handles this)
- ❌ Scope validation (git handles invalid scopes)
- ❌ Complex error handling and recovery

#### 1.3: Remove `test_ssh_auth()` Entirely
**Rationale**: Network dependency violates performance goals and CLI-first philosophy. Users discover SSH issues naturally when using git commands.

### Phase 2: Add Smart Detection

#### 2.1: Smart SSH Key Detection
```bash
detect_ssh_keys() {
    local username="$1"
    local ssh_dir="$HOME/.ssh"
    
    # Find keys matching patterns (no ranking needed - show all options)
    find "$ssh_dir" -name "id_*${username}*" 2>/dev/null
    find "$ssh_dir" -name "${username}*" 2>/dev/null  
    find "$ssh_dir" -name "id_*github*" 2>/dev/null
    find "$ssh_dir" -name "id_ed25519" -o -name "id_rsa" 2>/dev/null
}
```

#### 2.2: Smart Permission Fixing
```bash
fix_ssh_permissions() {
    local ssh_key_path="$1"
    
    # Skip if not a regular file (handles symlinks, devices, etc.)
    [[ -f "$ssh_key_path" && ! -L "$ssh_key_path" ]] || return 0
    
    local current_perms=$(stat -c %a "$ssh_key_path" 2>/dev/null || stat -f %Lp "$ssh_key_path" 2>/dev/null)
    
    if [[ "$current_perms" != "600" ]]; then
        if chmod 600 "$ssh_key_path" 2>/dev/null; then
            echo "🔧 Fixed SSH key permissions ($current_perms → 600)"
        else
            echo "⚠️  Could not fix SSH key permissions (read-only filesystem?)"
        fi
    fi
}
```

**Permission Fixing Rationale:**
Auto-fixing SSH key permissions from 644→600 provides significant UX benefit:
- **Prevents cryptic SSH errors** during git operations
- **No legitimate use case** for SSH private keys to have permissions other than 600  
- **Industry standard practice** - all SSH private keys should be 600
- **Transparent operation** - clear notification about changes made
- **Graceful error handling** - handles edge cases like symlinks and read-only filesystems

#### 2.3: Enhanced `add_user()` Function
```bash
add_user() {
    local username="$1" 
    local ssh_key_path="$2"  # From --ssh-key flag
    
    if [[ -z "$ssh_key_path" ]]; then
        local keys=($(detect_ssh_keys "$username"))
        
        case ${#keys[@]} in
            0)
                echo "📝 No SSH keys found, using HTTPS"
                ;;
            1)
                ssh_key_path="${keys[0]}"
                fix_ssh_permissions "$ssh_key_path"
                echo "🔍 Found SSH key: $ssh_key_path"
                ;;
            *)
                echo "🔍 Found multiple SSH keys:"
                printf "  %s\n" "${keys[@]}"
                echo ""
                echo "Specify which one to use:"
                for key in "${keys[@]}"; do
                    echo "  ghs add-user $username --ssh-key $key"
                done
                return 1
                ;;
        esac
    fi
    
    # Validate if provided and create profile
    if [[ -n "$ssh_key_path" ]] && ! validate_ssh_key "$ssh_key_path"; then
        return 1
    fi
    
    create_user_profile "$username" "" "" "true" "$ssh_key_path"
    list_users
}
```

**Multiple Key Handling:**
- **Single key found**: Auto-select and continue
- **Multiple keys found**: Show copy-paste ready commands for each option
- **No keys found**: HTTPS mode with clear messaging
- **Manual override**: `--ssh-key` flag always takes precedence

### Phase 3: Simplified Testing

#### 3.1: Test Structure
Following project guidelines: **"Unit tests + ≥1 higher layer (not exhaustive coverage)"**

**Unit Tests** (`tests/unit/test_ssh_detection.bats`):
- Test SSH key detection patterns
- Test permission fixing logic
- Fast execution (<5s per file)

**Integration Tests** (`tests/integration/test_ssh_workflow.bats`):
- Test full user workflows with SSH keys
- Test multiple key scenarios
- Real file system operations in isolated environment

#### 3.2: Essential Test Scenarios

**Core Detection:**
```bash
@test "detects single SSH key matching username"
@test "shows multiple SSH keys with copy-paste commands"
@test "handles no SSH keys found gracefully"
@test "respects manual --ssh-key override"
```

**Permission Handling:**
```bash
@test "auto-fixes 644 permissions to 600 with notification"
@test "skips permission fix for symlinks"
@test "handles permission fix failure gracefully"
```

**Integration Workflows:**
```bash
@test "add user with single SSH key detected"
@test "add user with multiple SSH keys shows options"
@test "add user with HTTPS fallback"
@test "manual override works correctly"
```

#### 3.3: Simple Test Infrastructure

**SSH Test Helper** (`tests/helpers/ssh_helper.bash`):
```bash
create_test_ssh_key() {
    local name="$1" perms="${2:-600}"
    local key_file="$TEST_HOME/.ssh/$name"
    mkdir -p "$TEST_HOME/.ssh"
    
    # Create fake SSH key
    echo "-----BEGIN PRIVATE KEY-----" > "$key_file"
    echo "fake-key-content" >> "$key_file"  
    echo "-----END PRIVATE KEY-----" >> "$key_file"
    chmod "$perms" "$key_file"
}

assert_key_permissions() {
    local key_file="$1" expected="$2"
    local actual=$(stat -c %a "$key_file" 2>/dev/null || stat -f %Lp "$key_file" 2>/dev/null)
    [[ "$actual" == "$expected" ]]
}
```

## Implementation Checklist

### Phase 1: Simplification
- [ ] Replace `validate_ssh_key()` with 8-line version
- [ ] Replace `apply_ssh_config()` with 12-line version  
- [ ] Remove `test_ssh_auth()` function entirely
- [ ] Remove Base64 encoding complexity from profiles
- [ ] Update profile format to store SSH key paths as plain text
- [ ] Verify existing tests still pass with simplified functions

### Phase 2: Smart Features
- [ ] Implement `detect_ssh_keys()` function
- [ ] Implement `fix_ssh_permissions()` function
- [ ] Update `add_user()` to use smart detection and multiple key handling
- [ ] Add `--ssh-key` and `--no-ssh` flag parsing
- [ ] Update help text and examples

### Phase 3: Testing
- [ ] Create `tests/helpers/ssh_helper.bash` with simple test utilities
- [ ] Write unit tests for detection and permission fixing
- [ ] Write integration tests for user workflows
- [ ] Write edge case tests for multiple keys and error scenarios
- [ ] Verify performance targets (<100ms command completion)

### Phase 4: Documentation
- [ ] Document edge cases and their solutions
- [ ] Update README.md with SSH examples
- [ ] Add troubleshooting section for common SSH issues
- [ ] Validate against project philosophy compliance

## Testing Plan

### Test Design Principles
- **Slim**: Test essential scenarios, avoid over-testing implementation details
- **Effective**: Focus on user workflows and failure modes that matter
- **Well-designed**: Clear test names, minimal setup, fast execution

### Test Categories
1. **Unit Tests**: Core functions (detection, permission fixing)
2. **Integration Tests**: User workflows (add-user, profile switching)
3. **Edge Case Tests**: Multiple keys, error scenarios, manual overrides

### Essential Test Scenarios

**Core Functionality (Must Work):**
```bash
@test "single SSH key detected and used automatically"
@test "multiple SSH keys show copy-paste commands"  
@test "no SSH keys found defaults to HTTPS"
@test "manual --ssh-key override works"
@test "permission auto-fix 644→600 with notification"
```

**Error Handling (Must Be Helpful):**
```bash
@test "missing SSH key file shows clear error"
@test "symlink SSH key skips permission fix"
@test "read-only filesystem permission fix fails gracefully"
```

**User Workflows (Integration):**
```bash
@test "end-to-end: add user with detected SSH key"
@test "end-to-end: add user with multiple key selection"
@test "end-to-end: profile switching applies SSH config"
```

### Test Quality Standards
- **Zero tolerance**: All tests must pass, no exceptions
- **Fast execution**: Unit tests <5s per file, integration <10s
- **Clear failure messages**: Test names describe exact scenario
- **Minimal mocking**: Use real file operations in test environment
- **No flaky tests**: Deterministic behavior only

## Status
**Current Status**: Planning Complete - Ready for Implementation

## Notes

### Key Metrics for Success
- **Code reduction**: 144 lines → ~30 lines (79% reduction)
- **Performance**: Remove network dependency from `add_user()`
- **Function compliance**: All functions <50 lines
- **Test coverage**: Essential scenarios + edge cases (not exhaustive)
- **Philosophy**: Restore "simple over complex" principle

### Risks and Mitigations
**Risk**: Smart detection guesses wrong SSH key
**Mitigation**: For multiple keys, show copy-paste commands instead of guessing

**Risk**: Auto-fixing permissions surprises users  
**Mitigation**: Clear notification when permissions are changed, skip symlinks

**Risk**: Removing network validation misses setup errors
**Mitigation**: Users discover issues naturally during git operations

### Future Enhancements (Post-Simplification)
- Optional GitHub SSH key testing (`ghs test-ssh username`)
- SSH key generation helper (`ghs generate-ssh username`)
- SSH key management commands (`ghs list-ssh-keys`)

These would be separate commands following CLI-first philosophy, not built into core workflows.