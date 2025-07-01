# REFACTOR-LazySSHValidation - Implement Lazy SSH Validation

## Task ID

REFACTOR-LazySSHValidation

## Problem Statement

Current SSH validation during user creation has several issues:
- **Performance Impact**: Testing GitHub SSH auth during `add-user` slows down the command
- **Network Dependency**: Fails in environments without internet access
- **Poor UX**: Command hangs if GitHub is slow or unreachable
- **Unnecessary Blocking**: User creation should be fast and lightweight

Current behavior: `ghs add-user work --ssh-key ~/.ssh/key` tests GitHub connectivity immediately.

## Proposed Solution

Implement lazy SSH validation that validates SSH keys only when needed, with explicit testing commands.

## Why It's Valuable

- **Faster User Creation** - No network calls during profile setup
- **Better Offline Support** - Can create profiles without internet
- **Explicit Testing** - Clear separation between profile creation and validation
- **Better Error Recovery** - SSH issues don't block profile management
- **Improved UX** - Fast, predictable command execution

## Technical Implementation

### New Validation Strategy

1. **Basic Validation During Creation**
   - File existence check
   - Permission validation (and auto-fix)
   - Basic format check (private key detection)
   - No network calls

2. **Lazy Validation During Use**
   - SSH authentication test on first profile switch
   - Cache validation results to avoid repeated tests
   - Clear feedback when SSH issues detected

3. **Explicit Testing Commands**
   - `ghs test-ssh <user>` - Test specific user's SSH configuration
   - `ghs test-ssh-all` - Test all users with SSH keys
   - `ghs fix-ssh <user>` - Fix SSH permissions and retest

### User Experience Flow

```bash
# Fast profile creation (no network calls)
$ ghs add-user work-account --ssh-key ~/.ssh/id_rsa_work
🔍 Validating SSH key file...
✅ SSH key found and readable
✅ Set permissions to 600
✅ Added work-account to user list
💡 Use 'ghs test-ssh work-account' to verify GitHub connectivity

# Explicit testing when ready
$ ghs test-ssh work-account
🔐 Testing GitHub authentication...
✅ SSH key authenticated as: work-account
✅ SSH configuration verified

# Or test during first switch
$ ghs switch 2
🔄 Switching to work-account...
🔐 Testing SSH key (first time)...
✅ SSH authenticated as: work-account
✅ Applied git config and SSH configuration
✅ Switched to work-account (#2)
```

### Implementation Changes

1. **Update `add_user()` Function**
   - Remove `test_ssh_auth()` call during creation
   - Only perform local file validation
   - Add suggestion to test SSH separately

2. **Add SSH Testing Commands**
   - `test-ssh <user>` - Test specific user
   - `test-ssh-all` - Test all SSH-enabled users
   - Include testing in help and dashboard

3. **Update Profile Switching**
   - Test SSH on first use of each profile
   - Cache successful test results
   - Provide clear feedback for SSH issues

4. **Add SSH Status Tracking**
   - Track which SSH keys have been tested successfully
   - Show testing status in user listings
   - Cache test results to avoid repeated network calls

### Functions to Implement

- `test_user_ssh(username)` - Test specific user's SSH setup
- `test_all_user_ssh()` - Test all users with SSH keys
- `cache_ssh_test_result(username, success)` - Cache test results
- `get_ssh_test_status(username)` - Get cached test status
- `is_ssh_test_required(username)` - Check if testing needed

## Implementation Checklist

- [ ] Remove SSH testing from `add_user()` function
- [ ] Add SSH test result caching system
- [ ] Implement `test-ssh` command
- [ ] Implement `test-ssh-all` command
- [ ] Update profile switching to test on first use
- [ ] Add SSH test status to user listings
- [ ] Update help and documentation
- [ ] Add suggestions for SSH testing in user creation
- [ ] Test offline profile creation scenarios

## Testing Plan

1. **Offline Functionality Tests**
   - Create profiles without internet connection
   - Verify basic SSH validation works offline
   - Test graceful handling of network failures

2. **Lazy Validation Tests**
   - Create profile, then test SSH separately
   - Switch to profile and verify first-time testing
   - Test caching of SSH validation results

3. **Explicit Testing Commands**
   - Test individual user SSH configuration
   - Test all users with mixed SSH/HTTPS profiles
   - Verify clear error messages for SSH failures

4. **Performance Tests**
   - Measure user creation time before/after change
   - Verify no network calls during profile creation
   - Test responsiveness in slow network conditions

## Status

Not Started

## Notes

- SSH test results should be cached to avoid repeated network calls
- Cache should be invalidated if SSH key path changes
- Consider adding SSH test timestamps to track when last tested
- Provide clear guidance on when SSH testing is recommended