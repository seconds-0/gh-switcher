# SSH Testing Implementation Plan

## Overview
Complete the SSH key integration by adding actual authentication testing with GitHub. This prevents failed git operations by verifying SSH keys work during profile operations.

## Problem Statement
Currently, gh-switcher validates SSH key files exist and have correct permissions, but doesn't test if they actually authenticate with GitHub. Users discover authentication failures only when pushing/pulling, which is frustrating and breaks workflow.

## Success Criteria
- SSH keys tested during `ghs add` command
- Manual `ghs test-ssh` command for troubleshooting
- Clear distinction between network issues and auth failures
- <100ms performance maintained (use timeouts)
- No network dependency for other operations

## Implementation Design

### 1. Simple SSH Test Function
```bash
# Test SSH authentication with GitHub
test_ssh_auth() {
    local ssh_key="$1"
    
    # Test GitHub SSH with specific key
    # Using SSH's built-in timeout for portability (no external timeout command)
    local output
    if output=$(ssh -T git@github.com \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=3 \
        -o ServerAliveInterval=3 \
        -o ServerAliveCountMax=1 \
        -o IdentitiesOnly=yes \
        -o IdentityFile="$ssh_key" \
        2>&1); then
        # SSH returns 1 even on success, check the output
        [[ "$output" =~ "successfully authenticated" ]] && return 0
    fi
    
    # Simple categorization
    if [[ "$output" =~ "Permission denied" ]]; then
        echo "auth_failed"
        return 1
    else
        echo "connection_failed"  
        return 2
    fi
}
```

### 2. Integration in `ghs add`
```bash
# In cmd_add(), after SSH key validation:
if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
    echo "🔐 Testing SSH authentication..."
    result=$(test_ssh_auth "$ssh_key")
    case "$?" in
        0)  # Success
            echo "✅ SSH key authenticated successfully"
            ;;
        1)  # Auth failed
            echo "❌ SSH key not recognized by GitHub"
            echo
            echo "   The key exists but GitHub rejected it. This usually means:"
            echo "   • Key not added to GitHub: https://github.com/settings/keys"
            echo "   • Key is for a different account"
            echo
            echo -n "   Add profile anyway? (y/N) "
            read -r response
            [[ ! "$response" =~ ^[Yy]$ ]] && return 1
            ;;
        2)  # Network issue
            echo "⚠️  Cannot reach GitHub to test SSH key"
            echo
            echo "   Unable to verify authentication due to network issues."
            echo "   The SSH key configuration looks correct."
            echo
            echo "   You can test manually later with: ghs test-ssh $username"
            echo
            echo -n "   Continue adding profile? (Y/n) "
            read -r response
            [[ "$response" =~ ^[Nn]$ ]] && return 1
            ;;
    esac
fi
```

### 3. New Manual Test Command
```bash
# Manual SSH test command for troubleshooting
cmd_test_ssh() {
    local username="${1:-$(get_current_user)}"
    local quiet=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet|-q)   quiet=true; shift ;;
            *)           username="$1"; shift ;;
        esac
    done
    
    # Get SSH key for user
    local profile ssh_key
    profile=$(profile_get "$username") || {
        [[ "$quiet" == "true" ]] && return 1
        echo "❌ User not found: $username"
        return 1
    }
    
    ssh_key=$(profile_get_field "$profile" "ssh_key")
    if [[ -z "$ssh_key" ]]; then
        [[ "$quiet" == "true" ]] && return 0
        echo "ℹ️  No SSH key configured for $username"
        echo "   This profile uses HTTPS authentication"
        return 0
    fi
    
    [[ "$quiet" != "true" ]] && {
        echo "🔐 Testing SSH authentication for $username..."
        echo "   Key: ${ssh_key/#$HOME/~}"
    }
    
    local result
    result=$(test_ssh_auth "$ssh_key")
    local exit_code=$?
    
    [[ "$quiet" == "true" ]] && return $exit_code
    
    case "$exit_code" in
        0)
            echo "✅ SSH authentication successful"
            echo "   GitHub recognizes this key"
            ;;
        1)
            echo "❌ SSH authentication failed"
            echo
            echo "   GitHub rejected this SSH key. To fix:"
            echo "   1. Copy your public key: cat ${ssh_key}.pub | pbcopy"
            echo "   2. Add it to GitHub: https://github.com/settings/keys"
            echo "   3. Test again: ghs test-ssh $username"
            ;;
        2)
            echo "⚠️  Network issue - cannot reach GitHub"
            echo
            echo "   Possible causes:"
            echo "   • No internet connection"
            echo "   • GitHub is down (check https://githubstatus.com)"
            echo "   • Firewall blocking SSH port 22"
            echo
            echo "   Try: ssh -T git@github.com -p 443 (uses HTTPS port)"
            ;;
    esac
    
    return $exit_code
}
```

### 4. Usage Examples

#### In Pre-commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Ensure SSH works before allowing commit
if ! ghs test-ssh --quiet; then
    echo "⚠️  SSH authentication failed - push may fail"
    echo "Run 'ghs test-ssh' for details"
    exit 1
fi
```

#### For Debugging
```bash
# Test current user
$ ghs test-ssh

# Test specific user
$ ghs test-ssh alice

# Quiet mode for scripts (exit code only)
$ ghs test-ssh --quiet && echo "SSH OK" || echo "SSH Failed"
```

### 6. Help Text Updates
```bash
# Add to cmd_help()
echo "  test-ssh [<user>]        Test SSH authentication for a user"
echo "    --quiet, -q            Exit code only (for scripts)"
```

## Testing Plan

1. **Unit Tests**
   - Mock ssh command for predictable results
   - Test parsing of various SSH error messages
   - Test exit codes for different scenarios

2. **Integration Tests**
   - Test with valid SSH key
   - Test with invalid SSH key  
   - Test with network failures
   - Test with SSH timeout
   - Test quiet mode

3. **Edge Cases**
   - GitHub.com unreachable but key is valid
   - SSH port 22 blocked (firewall)
   - DNS resolution failures
   - Timeout scenarios
   - Missing ssh command

## Implementation Order

1. Implement `test_ssh_auth()` function (simple version)
2. Implement `cmd_test_ssh()` command
3. Integrate into `cmd_add()` with smart defaults
4. Update help text and documentation
5. Write comprehensive tests

## Risks & Mitigations

- **Risk**: Network dependency slows down commands
  - **Mitigation**: 3-second timeout, smart defaults for network issues

- **Risk**: False negatives from network issues
  - **Mitigation**: Clear distinction between network and auth failures

- **Risk**: Breaking offline-first principle
  - **Mitigation**: Only test during add (optional continue), manual test command

- **Risk**: Confusing users with network errors
  - **Mitigation**: Different messaging and defaults for each scenario

## Future Enhancements

1. **Alternative ports**: Auto-try port 443 if 22 fails (for firewalls)
2. **Batch testing**: `ghs test-ssh --all` to test all configured users