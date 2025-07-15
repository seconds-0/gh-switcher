# E2E Tests Phase 2 Plan - Core Functions

## Overview
This plan details 6 core function test suites to add comprehensive E2E testing coverage for gh-switcher. Each suite tests real-world usage patterns with proper edge case handling.

## 1. Project Assignment Flow Tests

### Core Functionality Tests
```bash
# Test 1.1: Basic project assignment
@test "e2e: project assignment: basic assign and auto-switch" {
    # Setup: Create project directory, add users
    # Action: ghs assign testuser1
    # Verify: .ghs-project file created with correct content
    # Action: cd out and back in
    # Verify: Auto-switches to testuser1
}

# Test 1.2: Override existing assignment
@test "e2e: project assignment: override existing assignment" {
    # Setup: Existing assignment to user1
    # Action: ghs assign user2
    # Verify: Prompts for confirmation, updates assignment
}

# Test 1.3: Nested project assignments
@test "e2e: project assignment: nested directories respect closest assignment" {
    # Setup: Parent dir assigned to user1, child to user2
    # Action: Enter child directory
    # Verify: Switches to user2 (closest assignment wins)
}
```

### Edge Cases
```bash
# Test 1.4: Assignment without git repo
@test "e2e: project assignment: works outside git repositories" {
    # Setup: Regular directory (no .git)
    # Action: ghs assign
    # Verify: Creates .ghs-project file, assignment works
}

# Test 1.5: Assignment with missing user
@test "e2e: project assignment: handles missing assigned user gracefully" {
    # Setup: Assign user1, then remove user1
    # Action: cd into directory
    # Verify: Shows warning, doesn't crash, suggests fix
}

# Test 1.6: Corrupted project file
@test "e2e: project assignment: handles corrupted .ghs-project file" {
    # Setup: Create invalid .ghs-project content
    # Action: cd into directory
    # Verify: Shows error, ignores corrupted file, continues
}

# Test 1.7: Permission issues
@test "e2e: project assignment: handles read-only directories" {
    # Setup: Directory without write permissions
    # Action: ghs assign
    # Verify: Shows appropriate error about permissions
}
```

## 2. Git Config Integration Tests

### Core Functionality Tests
```bash
# Test 2.1: Local git config changes
@test "e2e: git config: switch updates local git config" {
    # Setup: Git repo with existing config
    # Action: ghs switch user1
    # Verify: git config user.name and user.email updated
    # Verify: Only local config changed, not global
}

# Test 2.2: Global git config changes
@test "e2e: git config: switch --global updates global config" {
    # Setup: No local git repo
    # Action: ghs switch user1 --global
    # Verify: Global git config updated
    # Verify: Works outside git repositories
}

# Test 2.3: Git config preservation
@test "e2e: git config: preserves other git config values" {
    # Setup: Git config with custom settings
    # Action: ghs switch
    # Verify: Only user.name/email changed, others preserved
}
```

### Edge Cases
```bash
# Test 2.4: Special characters in git config
@test "e2e: git config: handles special characters in names/emails" {
    # Setup: User with quotes, spaces, unicode in name
    # Action: ghs switch
    # Verify: Git config properly escaped/quoted
}

# Test 2.5: Git config conflicts
@test "e2e: git config: handles includeIf and conditional includes" {
    # Setup: Git config with includeIf directives
    # Action: ghs switch
    # Verify: Respects git's config hierarchy
}

# Test 2.6: Concurrent git operations
@test "e2e: git config: safe during concurrent git operations" {
    # Setup: Start long-running git operation
    # Action: ghs switch in parallel
    # Verify: No corruption, proper locking
}

# Test 2.7: Git worktrees
@test "e2e: git config: works correctly with git worktrees" {
    # Setup: Git worktree with separate config
    # Action: ghs switch in worktree
    # Verify: Updates correct config for worktree
}
```

## 3. SSH Key Authentication Tests

### Core Functionality Tests
```bash
# Test 3.1: Basic SSH authentication test
@test "e2e: ssh auth: test-ssh validates key successfully" {
    # Setup: User with valid SSH key
    # Action: ghs test-ssh user1
    # Verify: Shows success message
    # Verify: Exit code 0
}

# Test 3.2: SSH auth with different key types
@test "e2e: ssh auth: supports ed25519 and RSA keys" {
    # Setup: Users with different key types
    # Action: ghs test-ssh for each
    # Verify: Both key types work correctly
}

# Test 3.3: SSH auth with custom host
@test "e2e: ssh auth: tests against correct host" {
    # Setup: User on enterprise host
    # Action: ghs test-ssh enterprise-user
    # Verify: Tests against enterprise host, not github.com
}
```

### Edge Cases
```bash
# Test 3.4: SSH key not in agent
@test "e2e: ssh auth: handles key not loaded in ssh-agent" {
    # Setup: Valid key file but not in agent
    # Action: ghs test-ssh
    # Verify: Attempts with key file directly
    # Verify: Suggests adding to agent
}

# Test 3.5: Network failures
@test "e2e: ssh auth: distinguishes network vs auth failures" {
    # Setup: Block network to GitHub
    # Action: ghs test-ssh
    # Verify: Shows network error, not auth error
}

# Test 3.6: SSH key with passphrase
@test "e2e: ssh auth: handles passphrase-protected keys" {
    # Setup: Key with passphrase
    # Action: ghs test-ssh
    # Verify: Prompts for passphrase or shows appropriate message
}

# Test 3.7: Multiple keys for same user
@test "e2e: ssh auth: picks correct key from multiple options" {
    # Setup: User with multiple SSH keys
    # Action: ghs test-ssh
    # Verify: Uses the configured key, not others
}
```

## 4. Profile Management Tests

### Core Functionality Tests
```bash
# Test 4.1: Profile display with issue detection
@test "e2e: profile: show detects and reports issues" {
    # Setup: User with missing SSH key, typo in email
    # Action: ghs show user1
    # Verify: Shows profile info
    # Verify: Lists detected issues clearly
}

# Test 4.2: Profile editing with validation
@test "e2e: profile: edit validates changes" {
    # Setup: Existing user profile
    # Action: ghs edit user1 --email=invalid
    # Verify: Rejects invalid email format
    # Action: ghs edit user1 --ssh-key=/nonexistent
    # Verify: Warns about missing key
}

# Test 4.3: Profile format migration
@test "e2e: profile: handles legacy format migration" {
    # Setup: Old format profile file
    # Action: ghs show user1
    # Verify: Migrates to new format transparently
    # Verify: Preserves all data
}
```

### Edge Cases
```bash
# Test 4.4: Profile corruption recovery
@test "e2e: profile: recovers from corrupted profile data" {
    # Setup: Partially corrupted profile file
    # Action: ghs show user1
    # Verify: Shows what it can, reports corruption
    # Verify: Offers recovery options
}

# Test 4.5: Profile with missing user data
@test "e2e: profile: handles profiles without git config" {
    # Setup: User in users file but no profile
    # Action: ghs show user1
    # Verify: Prompts to create profile
    # Verify: Shows helpful next steps
}

# Test 4.6: Concurrent profile edits
@test "e2e: profile: handles concurrent edit operations" {
    # Setup: Two ghs edit commands in parallel
    # Action: Run both simultaneously
    # Verify: No data loss, proper locking
}

# Test 4.7: Profile path edge cases
@test "e2e: profile: handles special characters in paths" {
    # Setup: SSH key with spaces, unicode in path
    # Action: ghs edit --ssh-key="path with spaces"
    # Verify: Properly quotes/escapes in storage
}
```

## 5. Current User Detection Tests

### Core Functionality Tests
```bash
# Test 5.1: Add current authenticated user
@test "e2e: current user: add --current detects gh auth" {
    # Setup: gh auth login with testuser
    # Action: ghs add --current
    # Verify: Detects and adds authenticated user
    # Verify: Pulls correct email from gh api
}

# Test 5.2: Status shows current active user
@test "e2e: current user: status displays active user correctly" {
    # Setup: Multiple users, one active
    # Action: ghs status
    # Verify: Shows current user prominently
    # Verify: Shows git config match status
}

# Test 5.3: Current user with no profile
@test "e2e: current user: handles user without profile gracefully" {
    # Setup: User in list but no profile
    # Action: ghs status
    # Verify: Shows user but indicates missing profile
}
```

### Edge Cases
```bash
# Test 5.4: No authenticated gh user
@test "e2e: current user: add --current fails gracefully without auth" {
    # Setup: gh auth logout
    # Action: ghs add --current
    # Verify: Clear error about needing gh auth
    # Verify: Suggests gh auth login
}

# Test 5.5: Multiple gh auth states
@test "e2e: current user: handles multiple gh configs" {
    # Setup: gh authenticated to multiple hosts
    # Action: ghs add --current
    # Verify: Prompts which host to use
    # Verify: Or uses --host flag
}

# Test 5.6: Expired gh token
@test "e2e: current user: detects expired authentication" {
    # Setup: Expired gh token
    # Action: ghs add --current
    # Verify: Detects auth failure
    # Verify: Suggests reauth
}

# Test 5.7: Git config mismatch detection
@test "e2e: current user: status warns about mismatches" {
    # Setup: Active ghs user != git config
    # Action: ghs status
    # Verify: Shows warning about mismatch
    # Verify: Suggests fix
}
```

## 6. Multi-Host Support Tests

### Core Functionality Tests
```bash
# Test 6.1: Add users on different hosts
@test "e2e: multi-host: manages users across different hosts" {
    # Setup: Add user1@github.com, user2@enterprise.com
    # Action: ghs users
    # Verify: Shows host for each user
    # Verify: Formats display correctly
}

# Test 6.2: Switch between different hosts
@test "e2e: multi-host: switches users on different hosts" {
    # Setup: Users on different hosts
    # Action: ghs switch enterprise-user
    # Verify: Updates git config with correct host
    # Verify: SSH config points to right host
}

# Test 6.3: Host-specific email generation
@test "e2e: multi-host: generates correct default emails" {
    # Setup: Add users without specifying email
    # Action: ghs add user@enterprise.com
    # Verify: Email is user@enterprise.com
    # Action: ghs add user (on github.com)  
    # Verify: Email is user@users.noreply.github.com
}
```

### Edge Cases
```bash
# Test 6.4: Invalid host formats
@test "e2e: multi-host: validates host format" {
    # Setup: Try various invalid hosts
    # Action: ghs add user --host=invalid..host
    # Verify: Rejects invalid formats
    # Verify: Shows valid format examples
}

# Test 6.5: Host connectivity issues
@test "e2e: multi-host: handles unreachable hosts gracefully" {
    # Setup: User on host that's unreachable
    # Action: ghs test-ssh
    # Verify: Distinguishes host unreachable vs auth fail
}

# Test 6.6: Same username different hosts
@test "e2e: multi-host: handles identical usernames on different hosts" {
    # Setup: john@github.com and john@enterprise.com
    # Action: ghs switch john
    # Verify: Prompts which host or shows both
    # Verify: Can distinguish in all commands
}

# Test 6.7: Host-specific SSH configs
@test "e2e: multi-host: respects ~/.ssh/config host settings" {
    # Setup: ~/.ssh/config with custom host settings
    # Action: ghs operations
    # Verify: Doesn't override ssh config settings
    # Verify: Works with custom ports, jump hosts
}
```

## Implementation Notes

### Test Helpers Needed
```bash
# helpers/e2e_phase2_helper.bash

# Git config state management
save_git_config() { }
restore_git_config() { }

# SSH test infrastructure  
create_mock_ssh_endpoint() { }
simulate_network_failure() { }

# Profile manipulation
corrupt_profile_file() { }
create_legacy_profile() { }

# Multi-host mocking
mock_github_enterprise() { }
mock_gh_multi_auth() { }
```

### Performance Targets
- Each test: <500ms
- Test suite: <10 seconds total
- Parallel execution where possible

### Coverage Goals
- All happy paths
- Common error scenarios
- Edge cases that could cause data loss
- Shell compatibility issues

### Priority Order
1. Git Config Integration (most critical)
2. Project Assignment (most used)
3. SSH Authentication (most complex)
4. Multi-Host Support (enterprise users)
5. Profile Management (power users)
6. Current User Detection (convenience)