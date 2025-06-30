# FEAT-EnhancedProfileData - Enhanced Profile Data Management

## Task ID

FEAT-EnhancedProfileData

## Problem Statement

Current profile system stores minimal data (username only), leading to:

- No visibility into what configuration will be applied
- Cannot see signing keys, SSH keys, or other settings
- Difficult to debug configuration issues
- No validation of profile completeness
- Manual configuration required after switching

## Proposed Solution

Enhance profiles to store and display complete git configuration data including name, email, signing keys, SSH keys, and custom settings.

## Why It's Valuable

- **Complete visibility** - See all profile details at a glance
- **Prevents mistakes** - Know exactly what will be applied
- **Debugging aid** - Quickly spot configuration issues
- **Professional feel** - Rich data display builds confidence
- **Enables other features** - Foundation for SSH integration, GPG signing, etc.

## Implementation Details

### Core Functionality

1. **Extended Profile Data**

   - Git user name
   - Git user email
   - GPG signing key
   - SSH key path (for future SSH integration)
   - Auto-sign preference
   - GitHub username
   - Last used timestamp
   - Custom git config options

2. **Profile Management**

   - Create profiles with full data
   - Edit existing profiles
   - Import from current git config
   - Validate profile completeness
   - Profile health checks

3. **Rich Display**
   - Show all profile data in lists
   - Indicate incomplete profiles
   - Show last used information
   - Display current mismatches

### User Experience

#### Creating Profile with Auto-Detection

```bash
$ ghs add-user work
🔍 Detecting current git configuration...

📋 Found git config:
   Name: John Doe
   Email: john@company.com
   Signing Key: ABC123DEF456

✅ Use these values for work profile? (y/n/edit): edit

📝 Edit profile for work:
   Name [John Doe]: John Smith
   Email [john@company.com]: john.smith@company.com
   Signing Key [ABC123DEF456]: <enter to keep>
   Auto-sign commits [no]: yes
```

#### Rich Profile Display

```bash
$ ghs users
📋 GitHub Account Profiles:

🟢 1. personal-acct (current)
     Name: John Doe
     Email: john@personal.com
     Auth: HTTPS (GitHub CLI)
     Last used: 2 hours ago

⚪ 2. work [⚠️ Incomplete]
     Name: John Smith
     Email: john.smith@company.com
     GPG: ABC123DEF456 ✅
     Auto-sign: yes
     Missing: GitHub authentication
```

#### Profile Validation

```bash
$ ghs validate
🏥 Profile Health Check

✅ personal-acct (#1)
   - Git config: Valid
   - GitHub auth: Authenticated
   - GPG key: Not configured

⚠️  work (#2)
   - Git config: Valid
   - GitHub auth: NOT AUTHENTICATED
   - GPG key: Configured but not in keyring

   Fix: gh auth login
```

#### Profile Editing

```bash
$ ghs edit 2
📝 Editing profile: work (#2)

Current values:
1. Name: John Smith
2. Email: john.smith@company.com
3. GPG Key: ABC123DEF456
4. Auto-sign: yes

Select field to edit (1-4, s to save, c to cancel): 3
Enter new GPG Key: DEF789GHI012
✅ GPG key validated
```

## Technical Implementation

### Data Storage Enhancement

```bash
# Current format:
username

# New format (version 1):
username:1:base64(name):base64(email):base64(gpg_key):base64(ssh_key):auto_sign:last_used

# Simple format - no custom config needed
```

### Profile Structure

```bash
# Internal representation (simplified)
profile = {
    "username": "work-account",
    "version": 1,
    "name": "John Smith",
    "email": "john.smith@company.com",
    "gpg_key": "ABC123DEF456",
    "ssh_key": "~/.ssh/id_rsa_work",
    "auto_sign": true,
    "last_used": "2024-01-15T10:30:00Z"
}
```

### Functions to Implement

- `capture_current_config()` - Detect current git configuration
- `validate_profile_data()` - Check profile completeness
- `edit_profile_interactive()` - Interactive profile editing
- `display_rich_profile()` - Format profile for display
- `apply_full_profile()` - Apply all profile settings

## Migration Strategy

1. Detect old format (username only)
2. Prompt to enhance with current git config
3. Preserve existing profile numbers
4. Simple backup: `cp "$GH_USER_PROFILES" "$GH_USER_PROFILES.backup"`

## Testing Plan

1. Test migration from old format
2. Test profile validation
3. Test editing workflows
4. Test display with various data combinations
5. Test custom config options

## Status

Not Started

## Notes

- This is a prerequisite for SSH key integration
- Consider supporting profile templates
- May want to add profile export/import in JSON format
- Foundation for future team profile sharing
