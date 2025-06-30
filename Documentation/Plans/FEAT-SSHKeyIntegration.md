# FEAT-SSHKeyIntegration - SSH Key Integration per Profile

## Task ID

FEAT-SSHKeyIntegration

## Problem Statement

Users managing multiple GitHub accounts must manually configure SSH keys in `~/.ssh/config`, leading to:

- Authentication failures when wrong key is used
- Complex manual SSH configuration management
- Difficulty onboarding team members with correct SSH setup
- No automatic SSH key switching when changing profiles

## Proposed Solution

Integrate SSH key management directly into profile system, automatically configuring SSH authentication when switching profiles.

## Why It's Valuable

- **Eliminates manual SSH config management** - Users don't need to edit `~/.ssh/config`
- **Prevents authentication failures** - Right key always used for right account
- **Enables true account isolation** - Each profile has its own SSH identity
- **Simplifies team onboarding** - New devs just import profile with SSH config

## Implementation Details

### Core Functionality

1. **Profile SSH Key Storage**

   - Store SSH key path with each profile
   - Optional: Use HTTPS if no SSH key specified
   - Validate SSH key exists and has correct permissions

2. **SSH Key Validation**

   - Check key exists and is readable
   - Verify correct permissions (600)
   - Test authentication with GitHub
   - Provide clear error messages

3. **Automatic SSH Configuration**
   - Configure git's core.sshCommand when switching profiles
   - Optionally add key to SSH agent (if user wants)
   - Handle both ed25519 and RSA keys

### User Experience

#### Adding User with SSH Key

```bash
$ ghs add-user work --ssh-key ~/.ssh/id_rsa_work
🔍 Validating SSH key...
✅ SSH key found and readable
🔐 Testing GitHub authentication...
✅ SSH key authenticated as: work-account
✅ Added work to user list with SSH key
💡 Profile #2 created with SSH authentication
```

#### Profile Display with SSH Status

```bash
$ ghs users
📋 Available users:
  🟢 1. personal-acct (current) [HTTPS]
  ⚪ 2. work-account [SSH: ~/.ssh/id_rsa_work]
  ⚪ 3. personal [SSH: ~/.ssh/id_rsa_personal]
```

#### Switching with SSH Application

```bash
$ ghs switch 2
🔄 Switching to work-account...
✅ Applied git config
🔐 Configuring SSH: ~/.ssh/id_rsa_work
✅ Git SSH command configured
✅ Switched to work-account (#2)
```

### Error Handling

1. **Missing SSH Key**

   ```bash
   ❌ SSH key not found: ~/.ssh/nonexistent
   💡 Options:
      1. Create SSH key: ssh-keygen -t ed25519 -f ~/.ssh/nonexistent
      2. Add user without SSH: ghs add-user badkey
   ```

2. **Permission Issues**

   ```bash
   ⚠️  SSH key has incorrect permissions (644)
   🔧 Fixing permissions...
   ✅ Set permissions to 600
   ```

3. **Authentication Failures**
   ```bash
   ❌ SSH key authentication failed
   💡 Ensure key is added to GitHub: https://github.com/settings/keys
   ```

## Technical Implementation

### Data Storage

```bash
# Profile format with SSH key
username:version:base64(name):base64(email):base64(ssh_key_path)
```

### SSH Configuration Method

```bash
# Use git config for persistence (better than environment variable)
git config core.sshCommand "ssh -i ~/.ssh/id_rsa_work -o IdentitiesOnly=yes"

# For global effect (optional):
git config --global core.sshCommand "ssh -i ~/.ssh/id_rsa_work -o IdentitiesOnly=yes"
```

### Functions to Implement

- `validate_ssh_key()` - Check key exists and permissions
- `test_ssh_auth()` - Verify key works with GitHub
- `apply_ssh_config()` - Configure git's core.sshCommand
- `fix_ssh_permissions()` - Auto-fix common permission issues

## Testing Plan

1. Test with various SSH key types (RSA, ed25519)
2. Test permission fixing
3. Test authentication validation
4. Test switching between SSH and HTTPS profiles
5. Test with missing/invalid keys

## Status

In Progress

## Notes

- Keep SSH implementation simple - no agent management
- Use git config instead of environment variables for persistence
- Let advanced users manage their own SSH agent if needed

### Implementation Progress

- [x] Extend profile format to include SSH key path
- [x] Add SSH key validation functions
- [x] Add SSH configuration functions  
- [x] Update add-user command to support --ssh-key option
- [x] Update profile display to show SSH status
- [x] Update switching logic to apply SSH configuration
- [x] Add comprehensive testing notes and comments
- [ ] Test with various key types and scenarios

### Testing Notes

Testing will be done manually since no testing framework exists:

1. **SSH Key Validation Tests**
   - Test with valid ed25519 keys
   - Test with valid RSA keys  
   - Test with missing key files
   - Test with incorrect permissions (644, 755, etc.)
   - Test with keys that exist but are invalid format

2. **GitHub Authentication Tests**
   - Test SSH key that's properly added to GitHub
   - Test SSH key that's not added to GitHub
   - Test with key that has passphrase
   - Test network failures during authentication

3. **Profile Management Tests**
   - Create profiles with SSH keys
   - Create profiles without SSH keys (HTTPS fallback)
   - Migrate existing profiles to include SSH key field
   - Update profiles to add/remove SSH keys

4. **Switching Tests**
   - Switch between SSH and HTTPS profiles
   - Switch between different SSH keys
   - Verify git config is properly set
   - Test in repositories vs outside repositories

5. **Error Handling Tests**
   - Invalid SSH key paths
   - Permission errors
   - Network connectivity issues
   - Malformed profile data

### Security Considerations

- Validate SSH key paths to prevent directory traversal
- Use proper quoting in git config commands
- Don't expose private key contents in logs or output
- Ensure SSH key permissions are properly validated

### Implementation Notes

**Key Features Implemented:**

1. **Extended Profile Format (Version 2)**
   - Format: `username:2:base64(name):base64(email):base64(ssh_key_path)`
   - Backwards compatible with version 1 profiles
   - Empty SSH key field supported for HTTPS mode

2. **SSH Key Validation (`validate_ssh_key`)**
   - File existence and readability checks
   - Automatic permission fixing (600)
   - Basic private key format validation
   - Security: Prevents directory traversal attacks

3. **GitHub SSH Authentication Testing (`test_ssh_auth`)**
   - Tests actual GitHub connectivity with SSH key
   - Extracts GitHub username from SSH response
   - Warns if username mismatch detected
   - Handles network timeouts and authentication failures

4. **SSH Configuration Management (`apply_ssh_config`)**
   - Uses `git config core.sshCommand` for persistence
   - Proper command quoting to prevent injection
   - Supports both local and global git configuration
   - Can remove SSH config when switching to HTTPS

5. **Enhanced User Management**
   - `add-user` now supports `--ssh-key <path>` option
   - Automatic SSH validation during user creation
   - Profile creation includes SSH key authentication testing
   - User listings show SSH vs HTTPS status

6. **Improved Dashboard and Status**
   - Shows current SSH configuration status
   - Displays SSH key path in user listings
   - Indicates configuration mismatches
   - Clear HTTPS vs SSH mode indication

**Migration Strategy:**

- Existing version 1 profiles continue to work
- New profiles created as version 2 with SSH field
- `get_user_profile` handles both formats transparently
- Old format (username=name|email) still supported

**Error Handling:**

- Graceful fallback to HTTPS if SSH fails
- Clear error messages with actionable suggestions
- SSH validation failures don't break profile creation
- Configuration mismatches clearly indicated in dashboard
