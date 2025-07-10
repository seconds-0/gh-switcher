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

Partially Implemented

### Completed ✅
- Profile SSH key storage
- SSH key validation (file exists, permissions)
- SSH key path in profiles (v3 format)
- Auto-detection of alternative SSH keys
- Permission checking and fix suggestions
- SSH configuration via core.sshCommand
- Integration with add/edit/switch commands

### Remaining ❌
- SSH authentication testing with GitHub
- SSH key caching for performance
- See IMPLEMENTATION-SSH-Testing.md for completion plan

## Notes

- Keep SSH implementation simple - no agent management
- Use git config instead of environment variables for persistence
- Let advanced users manage their own SSH agent if needed
