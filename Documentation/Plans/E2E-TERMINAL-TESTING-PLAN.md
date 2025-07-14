# E2E Terminal Testing Plan for gh-switcher

## Overview
This document outlines a comprehensive end-to-end (E2E) testing approach for gh-switcher that tests the tool as users actually interact with it - through real terminal sessions. This approach will catch issues that unit tests miss, such as shell-specific bugs, environment interactions, and real-world usage patterns.

## Motivation
The recent zsh PATH bug that passed all unit tests but broke in real usage demonstrates the need for E2E terminal testing. Unit tests source the script directly, missing critical shell integration issues.

## Complete Function Inventory

### Core Commands (19 total)
1. `ghs` / `ghs status` - Show current user and status
2. `ghs add [username]` - Add new GitHub user
3. `ghs remove <username>` - Remove a user
4. `ghs switch <username|number>` - Switch GitHub account
5. `ghs users` - List all configured users
6. `ghs show <username>` - Show user profile details
7. `ghs edit <username> <field> <value>` - Edit user profile
8. `ghs assign <username> [directory]` - Assign user to directory
9. `ghs assign --list` - List all project assignments
10. `ghs assign --remove [directory]` - Remove project assignment
11. `ghs assign --clean` - Clean up invalid assignments
12. `ghs doctor` - Run system diagnostics
13. `ghs test-ssh [username]` - Test SSH key for user
14. `ghs help` - Show help message
15. `ghs auto-switch [on|off|status]` - Control auto-switching (future)

### Guard Subcommands (4 total)
1. `ghs guard install` - Install pre-commit hooks
2. `ghs guard uninstall` - Remove pre-commit hooks  
3. `ghs guard status` - Check guard hook status
4. `ghs guard test` - Test guard validation

## E2E Test Sequence

### Test Environment Setup
```bash
# Setup phase - Run once before all tests
export TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
export GH_USERS_FILE="$HOME/.config/gh-switcher/users"
export GH_PROFILES_FILE="$HOME/.config/gh-switcher/profiles"
export GH_PROJECT_CONFIG="$HOME/.config/gh-switcher/projects"

# Mock gh CLI for predictable testing
mkdir -p "$HOME/bin"
cat > "$HOME/bin/gh" << 'EOF'
#!/bin/bash
case "$*" in
    "auth status") echo "github.com logged in as testuser1" ;;
    "auth status --show-token") echo "Logged in to github.com as testuser1 (token: gho_xxxx)" ;;
    "api user -q .login") echo "${MOCK_CURRENT_USER:-testuser1}" ;;
    "auth switch --user testuser1") 
        export MOCK_CURRENT_USER=testuser1
        echo "✓ Switched to testuser1" 
        ;;
    "auth switch --user testuser2") 
        export MOCK_CURRENT_USER=testuser2
        echo "✓ Switched to testuser2" 
        ;;
    "auth switch --user "*) 
        echo "Error: User not found: ${*##--user }" >&2
        exit 1 
        ;;
    *) echo "Unknown gh command: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$HOME/bin/gh"
export PATH="$HOME/bin:$PATH"

# Mock SSH for testing
mkdir -p "$HOME/.ssh"
touch "$HOME/.ssh/testuser1_rsa" "$HOME/.ssh/testuser2_rsa"
chmod 600 "$HOME/.ssh/"*_rsa
```

### Test Sequence (Maintains Proper State)

#### Phase 1: Initial Setup and Basic Commands
```bash
# Test 1: Source and initial status
source ./gh-switcher.sh
ghs status  # Should show no current user

# Test 2: Add first user (interactive)
echo "testuser1" | ghs add
# Validate: User added to users file
[[ -f "$GH_USERS_FILE" ]] || { echo "FAIL: users file not created"; exit 1; }
grep -q "^testuser1$" "$GH_USERS_FILE" || { echo "FAIL: user not in file"; exit 1; }

# Test 3: Add second user (direct)
ghs add testuser2
# Validate: Two users in users file

# Test 4: List users
ghs users
# Validate: Shows testuser1 and testuser2

# Test 5: Switch to user by name
ghs switch testuser2
# Validate: gh auth switch called, current user is testuser2

# Test 6: Switch to user by number
ghs switch 1
# Validate: Switches to testuser1

# Test 7: Show user profile
ghs show testuser1
# Validate: Displays user profile information
```

#### Phase 2: Profile Management
```bash
# Test 8: Edit user name
ghs edit testuser1 name "Test User One"
# Validate: Profile updated with new name

# Test 9: Edit user email
ghs edit testuser1 email "test1@example.com"
# Validate: Profile updated with new email

# Test 10: Edit SSH key
ghs edit testuser1 ssh_key "$HOME/.ssh/test1_rsa"
# Validate: Profile updated with SSH key path

# Test 11: Show updated profile
ghs show testuser1
# Validate: All edits reflected in output
```

#### Phase 3: Project Assignment
```bash
# Test 12: Create test projects
mkdir -p "$TEST_HOME/work-project"
mkdir -p "$TEST_HOME/personal-project"

# Test 13: Assign user to directory
cd "$TEST_HOME/work-project"
ghs assign testuser1
# Validate: Assignment saved to projects file

# Test 14: Assign different user to different directory
cd "$TEST_HOME/personal-project"
ghs assign testuser2
# Validate: Both assignments in projects file

# Test 15: List assignments
ghs assign --list
# Validate: Shows both project assignments

# Test 16: Test assignment inheritance (subdirectory)
mkdir -p "$TEST_HOME/work-project/subdir"
cd "$TEST_HOME/work-project/subdir"
# Future: Should inherit testuser1 assignment

# Test 17: Remove assignment
ghs assign --remove "$TEST_HOME/personal-project"
# Validate: Assignment removed from projects file

# Test 18: Clean invalid assignments
rm -rf "$TEST_HOME/work-project"
ghs assign --clean
# Validate: Orphaned assignment removed
```

#### Phase 4: Guard Hooks and Git Integration
```bash
# Test 19: Initialize git repo
cd "$TEST_HOME"
git init test-repo
cd test-repo

# Test 20: Install guard hooks
ghs guard install
# Validate: Pre-commit hook created

# Test 21: Test guard validation
ghs guard test
# Validate: Shows current user would be used for commits

# Test 22: Switch user and test guard again
ghs switch testuser2
ghs guard test
# Validate: Shows testuser2 would be used

# Test 23: Check guard status
ghs guard status
# Validate: Shows hooks are installed

# Test 24: Uninstall guard hooks
ghs guard uninstall
# Validate: Pre-commit hook removed
```

#### Phase 5: Diagnostics and SSH
```bash
# Test 25: Run doctor command
ghs doctor
# Validate: All checks pass, no errors

# Test 26: Test SSH (will fail without real key)
ghs test-ssh testuser1
# Validate: Appropriate error message

# Test 27: Remove user
ghs remove testuser2
# Validate: User removed from users file and profiles
```

#### Phase 6: Error Cases and Edge Conditions
```bash
# Test 28: Switch to non-existent user
ghs switch nonexistent
# Validate: Error message

# Test 29: Edit non-existent user
ghs edit nonexistent name "Test"
# Validate: Error message

# Test 30: Invalid edit field
ghs edit testuser1 invalid "value"
# Validate: Error message

# Test 31: Duplicate user add
ghs add testuser1
# Validate: Error or handles gracefully
```

## Testing Approach

### Primary Tools
1. **BATS + expect** - For interactive command testing
2. **script command** - For recording terminal sessions
3. **Direct shell invocation** - For startup/sourcing tests

### Example E2E Test Implementation
```bash
#!/usr/bin/env bats

# Test real shell startup
@test "e2e: bash sources gh-switcher without errors" {
    run bash -c 'source ./gh-switcher.sh && echo "SUCCESS"'
    assert_success
    assert_output_contains "SUCCESS"
}

@test "e2e: zsh sources gh-switcher without breaking PATH" {
    # This is THE critical test - catches the bug that motivated E2E testing
    run zsh -c '
        original_path="$PATH"
        source ./gh-switcher.sh
        # Verify PATH still contains critical directories
        [[ "$PATH" == *"/usr/bin"* ]] || exit 1
        [[ "$PATH" == *"/bin"* ]] || exit 1
        # Verify ghs still works
        type ghs >/dev/null 2>&1 || exit 1
        echo "SUCCESS"
    '
    assert_success
    assert_output "SUCCESS"
}

@test "e2e: multiple sourcing doesn't fail on readonly variables" {
    run bash -c '
        source ./gh-switcher.sh
        source ./gh-switcher.sh  # Second source should not fail
        echo "SUCCESS"
    '
    assert_success
    assert_output "SUCCESS"
}

# Test interactive flow with expect
@test "e2e: interactive user addition" {
    cat > test_add_user.exp << 'EOF'
#!/usr/bin/expect
spawn bash -c "source ./gh-switcher.sh && ghs add"
expect "Enter GitHub username:"
send "interactiveuser\r"
expect "Added interactiveuser"
EOF
    
    run expect test_add_user.exp
    assert_success
}

# Test command sequence with state
@test "e2e: complete workflow" {
    # Use script to capture full session
    script -q session.log bash << 'EOF'
source ./gh-switcher.sh
ghs add alice
ghs add bob  
ghs switch bob
ghs status
exit
EOF
    
    assert_file_contains session.log "Switched to GitHub user: bob"
    assert_file_contains session.log "Current: bob"
}
```

## YAGNI/Overengineering Analysis

### What We're NOT Doing (YAGNI)
1. **Complex test frameworks** - No custom test harnesses or frameworks
2. **GUI automation** - Terminal only, no desktop integration testing
3. **Performance profiling** - Simple timing checks, not detailed profiling
4. **Cross-platform beyond Unix** - No Windows testing infrastructure
5. **Container-based testing** - Direct shell testing is sufficient
6. **Parallel test execution** - Sequential is fine for <50 tests
7. **Video recording** - Text logs are sufficient
8. **AI-powered test generation** - Manual test cases are clearer
9. **Test coverage metrics** - Focus on critical paths, not 100% coverage
10. **Mutation testing** - Overkill for a shell script

### Keeping It Simple
- Use existing Unix tools (expect, script, BATS)
- Focus on user-visible behavior, not internals
- Test real workflows, not every permutation
- Maintain test readability over cleverness
- Start with 10-15 critical tests, expand only if needed

### Potential Overengineering Risks
1. **31 tests might be too many** - Consider starting with core 10-15
2. **script command recording** - Adds complexity, simple run commands may suffice
3. **Complex state management** - Each test could use fresh environment
4. **Too many validation steps** - Focus on critical assertions only

## Supported Terminals

### In Scope
1. **bash** (4.0+) - Primary target
2. **zsh** (5.0+) - Must handle zsh-specific quirks
3. **sh** (POSIX) - Basic compatibility

### Testing Environments
1. **Direct terminal** - Standard Terminal.app, iTerm2, gnome-terminal
2. **VS Code integrated terminal** - Common developer environment
3. **tmux/screen** - Terminal multiplexers
4. **SSH sessions** - Remote usage

### Explicitly OUT OF SCOPE
1. **PowerShell** - Not a Unix shell
2. **fish shell** - Different syntax, would require rewrite
3. **nushell** - Not POSIX compatible
4. **Windows Terminal** - Focus on Unix-like systems
5. **Exotic shells** (rc, es, oil) - Insufficient user base

## Validation Approach

### For Each Test Step
1. **Input Validation**
   - Verify command accepts expected input
   - Check argument parsing
   - Validate error messages for bad input

2. **State Validation**
   - Check files are created/modified correctly
   - Verify environment variables are set
   - Confirm gh CLI was called with correct args

3. **Output Validation**
   - Exact string matching for critical output
   - Pattern matching for variable output
   - Exit code checking (0 for success, 1 for error)

4. **Side Effect Validation**
   - No unexpected files created
   - No environment pollution
   - Clean state after each test

### Success Criteria
- **Coverage**: Every user-facing command tested
- **Reliability**: Zero flaky tests
- **Performance**: Full suite runs in <30 seconds
- **Maintainability**: Clear test names and assertions
- **Debugging**: Helpful output when tests fail

## Implementation Priority

### Minimum Viable E2E Suite (Start Here)
Focus on the 10 tests that would have caught our recent bugs:
1. zsh PATH preservation test
2. Multiple sourcing test (readonly variables)
3. Basic user add/switch/remove flow
4. SSH key permission validation
5. Guard hook installation/removal
6. Project assignment basic flow
7. Error handling for missing user
8. Shell startup performance (<300ms)
9. VS Code terminal compatibility
10. Config file corruption recovery

### Phase 1 (Critical)
- Shell sourcing tests (catch PATH-like bugs)
- Basic command flow (add, switch, remove)
- State persistence validation

### Phase 2 (Important) 
- Interactive command testing
- Error case handling
- Git integration tests

### Phase 3 (Nice to Have)
- Performance benchmarks
- Complex workflow scenarios
- Edge case exploration

## Maintenance Guidelines

1. **Test Naming**: `e2e: <feature>: <specific behavior>`
2. **Test Independence**: Each test sets up its own state
3. **Cleanup**: Always clean up temp files and state
4. **Documentation**: Comment complex test logic
5. **Debugging**: Use DEBUG=1 flag for verbose output

## Conclusion

This E2E testing plan provides comprehensive coverage of gh-switcher's functionality through real terminal interactions. By focusing on actual user workflows and keeping the tooling simple, we can catch real-world issues while maintaining a manageable test suite. The key is testing what users actually do, not what we think they might do.