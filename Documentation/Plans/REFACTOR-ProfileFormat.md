# REFACTOR-ProfileFormat - Simplify Profile Storage Format

## Task ID

REFACTOR-ProfileFormat

## Problem Statement

Current profile format is overly complex and hard to debug/maintain:
- Uses base64 encoding for all fields (unnecessary for most data)
- Colon-separated format is fragile and hard to parse
- Multiple format versions create maintenance burden
- No human-readable profile inspection capability

Current format: `username:2:base64(name):base64(email):base64(ssh_key_path)`

## Proposed Solution

Implement individual profile files with simple key-value format for better maintainability and debuggability.

## Why It's Valuable

- **Easier debugging** - Human-readable profile files
- **Simpler parsing** - No base64 decoding complexity
- **Better extensibility** - Easy to add new fields without format version changes
- **Individual file management** - Can edit/inspect profiles directly
- **Reduced complexity** - Eliminates format versioning issues

## Technical Implementation

### New Profile Structure

```bash
# ~/.gh-switcher/profiles/username.profile
name=John Doe
email=john@example.com
ssh_key=~/.ssh/id_rsa_work
created=2024-01-15T10:30:00Z
version=1
```

### Directory Layout
```
~/.gh-switcher/
├── users                    # List of usernames (unchanged)
├── projects                 # Project assignments (unchanged)  
└── profiles/
    ├── work-account.profile
    ├── personal.profile
    └── client.profile
```

### Migration Strategy

1. **Backwards Compatibility Phase**
   - Keep existing `~/.gh-user-profiles` file working
   - New profiles created in new format
   - `get_user_profile()` checks new format first, falls back to old

2. **Migration Command**
   - `ghs migrate-profiles` - converts existing profiles to new format
   - Automatic migration prompt in dashboard if old profiles detected

3. **Cleanup Phase** (future)
   - After migration adoption, remove old format support

### Functions to Implement

- `get_profile_file_path(username)` - Returns path to profile file
- `write_profile_file(username, name, email, ssh_key)` - Write individual profile
- `read_profile_file(username)` - Read individual profile with fallback
- `migrate_profiles_to_files()` - Convert old format to new
- `list_profile_files()` - List all profile files

## Implementation Checklist

- [ ] Create profile directory structure
- [ ] Implement new profile file I/O functions
- [ ] Update `write_profile_entry()` to use new format
- [ ] Update `get_user_profile()` with fallback logic
- [ ] Add profile migration command
- [ ] Update profile listing to show new format
- [ ] Add backwards compatibility for old format
- [ ] Test migration scenarios
- [ ] Update documentation

## Testing Plan

1. **New Format Tests**
   - Create profiles with special characters in names/emails
   - Test SSH key paths with spaces and special chars
   - Verify profile file permissions (should be 644)

2. **Migration Tests**
   - Migrate v1 profiles (no SSH)
   - Migrate v2 profiles (with SSH)
   - Migrate old format profiles (username=name|email)
   - Test partial migration scenarios

3. **Backwards Compatibility Tests**
   - Mix of old and new format profiles
   - Verify fallback logic works correctly
   - Test with missing profile directories

## Status

Not Started

## Notes

- Profile files should be human-readable and editable
- Keep migration path simple and safe
- Consider adding metadata fields (created date, last used)
- Profile directory should be created automatically if missing