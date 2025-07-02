# TEST-ComprehensiveTestPlan.md

## Overview
This document compiles all test requirements identified throughout the gh-switcher codebase during the enhanced profile refactoring phase. These test comments guide future test implementation to ensure reliability of core functionality.

## Test Implementation Priority

### **CRITICAL (P0) - Data Integrity & Safety**
These tests protect user data and configuration integrity:

1. **test_write_profile_entry_atomicity()** - Profile file corruption protection
2. **test_project_assignment_atomicity()** - Project config corruption protection  
3. **test_migrate_old_profile_format()** - Migration safety and backup protection
4. **test_encode_profile_value() / test_decode_profile_value()** - Data encoding safety

### **HIGH (P1) - Core User Workflows**
These tests ensure primary user workflows function correctly:

1. **test_ghs_switch_command()** - Full user switching workflow
2. **test_ghs_add_user_command()** - User onboarding workflow
3. **test_update_profile_field()** - Profile management
4. **test_get_user_profile_backward_compatibility()** - Legacy format support

### **MEDIUM (P2) - Command Interface & UX**
These tests ensure CLI commands work as expected:

1. **test_ghs_profiles_command()** - Profile display functionality
2. **test_ghs_update_command()** - Update command interface
3. **test_ghs_default_dashboard()** - Smart dashboard display
4. **test_resolve_current_username()** - "current" user detection

### **LOW (P3) - Helper Functions & Edge Cases**
These tests catch edge cases and validate helper functions:

1. **test_validate_gpg_key()** - GPG validation edge cases
2. **test_apply_git_config()** - Git configuration edge cases
3. **test_check_git_availability()** - Git detection robustness

## Detailed Test Specifications

### File I/O & Data Safety Tests

#### test_write_profile_entry_atomicity()
**Purpose**: Ensure profile data cannot be corrupted by race conditions or failures
**Test Cases**:
- Kill process during write (temp file should be cleaned up)
- Concurrent writes (multiple processes, should not corrupt)
- Disk full during write (should fail gracefully, not corrupt)
- Permission denied on directory (should fail with clear message)
- Existing profile update (should replace, not duplicate)
- New profile creation (should add to file)
- Invalid filesystem move (different filesystems, should fail safely)

**Critical Failure Modes**: Profile data corruption, temp file leakage, silent failures

#### test_project_assignment_atomicity()
**Purpose**: Protect project configuration from corruption
**Test Cases**:
- Concurrent project assignments (should not corrupt file)
- Permission denied (should fail gracefully)
- Disk full during write (should fail safely)
- Process killed during operation (should cleanup temp file)
- Invalid project names (should validate/sanitize)
- Very long project names (should handle or limit)
- Special characters in project names (should escape properly)

**Critical Failure Modes**: Config file corruption, dangling temp files, injection attacks

#### test_encode_profile_value() / test_decode_profile_value()
**Purpose**: Ensure data encoding preserves all content safely
**Test Cases**:
- Empty string (should return empty encoded string)
- Simple ASCII text (should return valid base64)
- Unicode characters (should handle UTF-8 properly)
- Special characters: newlines, quotes, spaces (should encode safely)
- Very long strings (test performance/limits)
- Binary data (should handle any input)
- Round-trip test: encode→decode should equal original
- Invalid base64 input (should return empty string, not crash)
- Malformed base64 (should fail gracefully)

**Critical Failure Modes**: Data corruption, injection vulnerabilities, crashes on invalid input

### User Workflow Tests

#### test_ghs_switch_command()
**Purpose**: Validate complete user switching workflow
**Test Cases**:
- No user ID provided (should show usage, return 1)
- Invalid user ID (should return 1)
- Valid user ID (should switch GitHub auth and apply profile)
- GitHub switch failure (should return 1, show error)
- Profile application success (should show git config applied)
- Profile application failure (should warn but continue)
- Auto-profile creation when missing (should create and apply)
- Integration test: full switch workflow

**Critical Failure Modes**: Partial switches, data loss, authentication failures

#### test_ghs_add_user_command()
**Purpose**: Validate user onboarding workflows
**Test Cases**:
- No username provided (should show usage, return 1)
- Invalid username format (should return 1, show error)
- "current" keyword with no auth (should return 1)
- "current" keyword with auth (should detect and add user)
- Existing user (should prompt for recreation)
- New valid user (should add and create profile)
- Auto-detection success (should use detected values)
- Auto-detection failure (should fall back to manual)
- Manual entry with invalid data (should return 1)
- Manual entry with valid data (should create profile)

**Critical Failure Modes**: Duplicate users, failed auto-detection, invalid profiles

### Migration & Compatibility Tests

#### test_migrate_old_profile_format()
**Purpose**: Ensure safe migration without data loss
**Test Cases**:
- Missing profile file (should return 0, no-op)
- New format file (should return 0, no changes)
- Old format v0 (username=name|email, should migrate to v1)
- Old format v2 with SSH/timestamps (should migrate to v2.1)
- Mixed format file (some old, some new, should migrate only old)
- Corrupted old format (should fail gracefully, keep backup)
- Permission denied during migration (should fail safely)
- Backup creation failure (should abort migration)
- Large file migration (test performance)
- Special characters in old format (should handle properly)

**Critical Failure Modes**: Data loss during migration, corruption, failed backups

#### test_get_user_profile_backward_compatibility()
**Purpose**: Ensure legacy format support continues working
**Test Cases**:
- Version 0: username=name|email (should return structured data)
- Version 1: username:1:base64(name):base64(email) (should return with defaults)
- Version 2 old: username:2:name:email:gpg:ssh:auto:time (should ignore ssh/time)
- Version 2 new: username:2:name:email:gpg:auto (should parse correctly)
- Invalid version: username:99:... (should fail gracefully)
- Corrupted profile line (should fail gracefully, not crash)
- Empty profile file (should return 1)
- Multiple profiles for same user (should use first)

**Critical Failure Modes**: Incompatible format changes, parsing crashes, data loss

### Command Interface Tests

#### test_ghs_profiles_command()
**Purpose**: Validate profile display functionality
**Test Cases**:
- No profiles file (should show helpful message, return 0)
- Empty profiles file (should show helpful message, return 0)
- No --detailed flag (should call display_simple_profile)
- --detailed flag (should call display_rich_profile)
- Invalid flag (should default to simple, not crash)
- Large number of profiles (should be performant)
- Mixed profile formats (should handle gracefully via migration)
- Current user highlighting (should work with/without auth)

**Critical Failure Modes**: Performance issues, crashes on invalid data, incorrect display

#### test_update_profile_field()
**Purpose**: Validate profile field updates
**Test Cases**:
- Invalid field name (should return 1, show error)
- Empty value (should update to empty, return 0)
- Update by user number (should resolve and update)
- Update by username (should update directly)
- Update by "current" (should resolve current user and update)
- Non-existent user (should return 1, show error)
- User number out of range (should return 1)
- "current" when not authenticated (should return 1)
- Special characters in value (should handle safely)
- Very long value (should handle or limit appropriately)
- Profile write failure (should return 1, show error)

**Critical Failure Modes**: Invalid updates, data corruption, security issues

### Security & Input Validation Tests

#### test_get_user_by_id()
**Purpose**: Validate user ID resolution security
**Test Cases**:
- Invalid input: non-numeric (should return 1, show error)
- Invalid input: negative number (should return 1)
- Missing config file (should return 1, show error)
- Empty config file (should return 1, show error)
- User ID too high (ID=5 but only 3 users, should return 1)
- Valid ID=1 with users (should return 0, echo username)
- Valid ID=3 with 3 users (should return 0, echo username)
- Edge case: ID=0 (should return 1)

**Critical Failure Modes**: Buffer overflows, injection attacks, invalid memory access

#### test_validate_gpg_key()
**Purpose**: Validate GPG key validation robustness
**Test Cases**:
- Empty key (should return 0 - valid case)
- Missing gpg command (mock command -v to fail, should return 1)
- Invalid key ID (mock gpg --list-secret-keys to fail, should return 1)
- Valid key ID (mock gpg --list-secret-keys to succeed, should return 0)
- Special characters in key ID (test injection resistance)
- Very long key ID (test buffer limits)

**Critical Failure Modes**: Command injection, buffer overflows, false positives

### Utility & Helper Function Tests

#### test_resolve_current_username()
**Purpose**: Validate "current" user detection robustness
**Test Cases**:
- gh command not found (should return 1, show error)
- gh not authenticated (should return 1, show error)
- gh api fails (should return 1, show error)
- gh api returns empty (should return 1, show error)
- gh api returns valid username (should return 0, echo username)
- gh auth status passes but api fails (should return 1)
- Mock gh commands for isolated testing

**Critical Failure Modes**: False authentication detection, command injection, hanging calls

#### test_apply_git_config()
**Purpose**: Validate git configuration application
**Test Cases**:
- Invalid name/email (should return 1)
- Invalid scope parameter (should return 1)
- Not in git repo with local scope (should return 1)
- Git config set fails (mock git config to fail, should return 1)
- Git config verification fails (should return 1)
- Successful global config (should return 0, verify settings)
- Successful local config (should return 0, verify settings)
- Permission denied git config (should return 1)
- Git command not available (should return 1)

**Critical Failure Modes**: Unintended config changes, permission escalation, git repo corruption

## Test Implementation Strategy

### Test Framework Requirements
- **Isolation**: Each test should run in clean environment (temp directories, mock commands)
- **Mocking**: Mock external commands (gh, git, gpg) for reliable testing
- **Cleanup**: Automatic cleanup of temp files, directories, and config changes
- **Performance**: Tests should complete quickly (goal: <10s for full suite)
- **CI Integration**: Tests should run reliably in CI environment

### Test Data Management
- **Fixtures**: Pre-created test data for various profile formats and scenarios
- **Generators**: Functions to create test users, projects, and configurations
- **Sandboxing**: All tests operate in isolated temp directories
- **Backup/Restore**: Original configs preserved and restored after testing

### Error Testing Patterns
- **Partial Failures**: Test scenarios where operations partially succeed
- **Resource Constraints**: Test behavior under disk full, permission denied, etc.
- **Race Conditions**: Test concurrent operations and interruptions
- **Invalid Input**: Test all forms of malformed, malicious, and edge-case input

### Integration Test Scenarios
- **Full Workflow**: Complete user onboarding → switching → profile management cycle
- **Migration Scenarios**: Testing upgrade paths from all legacy formats
- **Multi-User Scenarios**: Testing with many users, projects, and complex configurations
- **Cross-Platform**: Testing on different shells, git versions, and environments

## Risk Assessment

### **HIGHEST RISK** (Require immediate testing)
1. **Profile Migration** - Risk of data loss during format upgrades
2. **File Atomicity** - Risk of configuration corruption 
3. **Backward Compatibility** - Risk of breaking existing users
4. **Input Validation** - Risk of command injection or data corruption

### **HIGH RISK** (Important for reliability)
1. **GitHub API Integration** - Risk of auth failures or API changes
2. **Git Configuration** - Risk of unintended repository changes
3. **User Switching Workflow** - Risk of partial switches or confusion

### **MEDIUM RISK** (Important for user experience)
1. **Error Handling** - Risk of unclear error messages or crashes
2. **Edge Cases** - Risk of unexpected behavior with unusual input
3. **Performance** - Risk of slowdowns with large configurations

## Testing Timeline Recommendation

### Phase 1: Critical Safety (Week 1)
- File atomicity tests
- Migration safety tests
- Input validation tests
- Data encoding tests

### Phase 2: Core Workflows (Week 2)
- User switching tests
- Profile management tests
- Command interface tests

### Phase 3: Integration & Polish (Week 3)
- Full workflow integration tests
- Error scenario tests
- Performance tests
- Cross-platform tests

## Success Criteria
- ✅ **Zero Data Loss**: No test should ever result in corrupted or lost user data
- ✅ **Graceful Failures**: All error conditions result in clear messages and safe recovery
- ✅ **Backward Compatibility**: All legacy formats continue to work correctly
- ✅ **Security**: No test reveals command injection or other security vulnerabilities
- ✅ **Performance**: Test suite completes in <30 seconds, individual commands <100ms
- ✅ **Reliability**: Tests pass consistently across different environments

---

**Note**: This test plan emerged from adding inline test comments throughout the codebase during major refactoring. The comments serve as specifications for implementing proper test coverage to protect this critical tool that manages developer authentication and git configuration.