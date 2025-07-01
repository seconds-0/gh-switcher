# FEAT-AutomatedTesting - Implement Automated Testing Framework

## Task ID

FEAT-AutomatedTesting

## Problem Statement

The gh-switcher codebase has grown in complexity (especially with SSH integration) but lacks automated testing:
- **Manual testing burden** - Complex feature interactions require extensive manual validation
- **Regression risk** - Changes can break existing functionality without detection
- **Confidence gap** - Difficult to refactor or add features safely
- **Documentation drift** - No executable verification that examples work

Current state: Only manual testing notes in code comments.

## Proposed Solution

Implement comprehensive automated testing using **bats (Bash Automated Testing System)** - the industry standard for bash script testing.

## Why bats Over Other Options

**Considered Alternatives:**
- **vitest** - Excellent for JS/TS but not suitable for bash scripts
- **shunit2** - Older bash testing framework, less active
- **Custom bash scripts** - Reinventing the wheel, maintenance burden

**Why bats is Best Choice:**
- **Designed for bash** - Native bash script testing framework
- **Popular & maintained** - De facto standard with active development
- **Readable syntax** - Tests look like natural bash with assertions
- **Rich ecosystem** - Helper libraries for common testing patterns
- **CI/CD friendly** - TAP output, exit codes, integration support

## Technical Implementation

### Testing Framework Structure

```bash
tests/
├── setup.bats                 # Test environment setup
├── test_user_management.bats   # User add/remove/list functionality
├── test_profile_management.bats # Profile creation/updates
├── test_ssh_integration.bats   # SSH key validation/config
├── test_project_assignment.bats # Project memory functionality
├── test_switching.bats         # User switching scenarios
├── test_migration.bats         # Profile format migrations
├── helpers/
│   ├── test_helper.bash        # Common test utilities
│   ├── ssh_helper.bash         # SSH testing utilities
│   └── git_helper.bash         # Git testing utilities
└── fixtures/
    ├── test_ssh_keys/          # Test SSH key pairs
    ├── sample_profiles/        # Sample profile data
    └── git_repos/              # Test git repositories
```

### Test Categories

1. **Unit Tests** - Individual function testing
   - Profile I/O functions
   - SSH validation functions
   - Git configuration functions
   - User management functions

2. **Integration Tests** - Feature workflow testing
   - Complete user creation workflow
   - Profile switching scenarios
   - SSH configuration application
   - Migration scenarios

3. **System Tests** - End-to-end scenarios
   - Multi-user project workflows
   - Mixed SSH/HTTPS environments
   - Error recovery scenarios

### Test Environment Management

```bash
# Test isolation strategy
setup() {
    export TEST_HOME="$BATS_TMPDIR/gh-switcher-test"
    export GH_PROJECT_CONFIG="$TEST_HOME/.gh-project-accounts"
    export GH_USERS_CONFIG="$TEST_HOME/.gh-users"
    export GH_USER_PROFILES="$TEST_HOME/.gh-user-profiles"
    
    mkdir -p "$TEST_HOME"
    create_test_ssh_keys
    setup_test_git_repos
}

teardown() {
    rm -rf "$TEST_HOME"
}
```

### Sample Test Structure

```bash
#!/usr/bin/env bats

load 'helpers/test_helper'

@test "add_user creates user profile with SSH key" {
    # Given
    create_test_ssh_key "test_rsa"
    
    # When
    run ghs add-user testuser --ssh-key "$TEST_HOME/test_rsa"
    
    # Then
    assert_success
    assert_output --partial "Added testuser to user list"
    assert_file_exists "$TEST_HOME/.gh-users"
    assert_profile_exists "testuser"
    assert_profile_has_ssh_key "testuser" "$TEST_HOME/test_rsa"
}

@test "switching users applies SSH configuration" {
    # Given
    setup_user_with_ssh "testuser" "$TEST_HOME/test_rsa"
    setup_git_repo "$TEST_HOME/test_repo"
    cd "$TEST_HOME/test_repo"
    
    # When
    run ghs switch 1
    
    # Then
    assert_success
    assert_git_config_set "core.sshCommand" "*test_rsa*"
    assert_git_config_set "user.name" "testuser"
}
```

### Testing Utilities

1. **SSH Testing Helpers**
   - Generate test SSH key pairs
   - Mock SSH authentication responses
   - Validate SSH configuration

2. **Git Testing Helpers**
   - Create isolated git repositories
   - Verify git configuration changes
   - Test git operations with SSH

3. **Profile Testing Helpers**
   - Create test profiles
   - Verify profile format/content
   - Test profile migrations

## Implementation Plan

### Phase 1: Foundation
- [ ] Install and configure bats
- [ ] Create basic test structure
- [ ] Implement test helpers and utilities
- [ ] Add simple unit tests for core functions

### Phase 2: Core Functionality  
- [ ] Test user management (add/remove/list)
- [ ] Test profile creation and updates
- [ ] Test basic switching functionality
- [ ] Test git configuration application

### Phase 3: SSH Integration
- [ ] Test SSH key validation
- [ ] Test SSH configuration application
- [ ] Test SSH authentication scenarios
- [ ] Test mixed SSH/HTTPS environments

### Phase 4: Advanced Scenarios
- [ ] Test migration scenarios
- [ ] Test error handling and recovery
- [ ] Test edge cases and boundary conditions
- [ ] Test performance scenarios

### Phase 5: CI/CD Integration
- [ ] Add GitHub Actions workflow
- [ ] Test on multiple environments (Linux, macOS)
- [ ] Add test coverage reporting
- [ ] Integrate with development workflow

## Installation and Setup

```bash
# Install bats-core
# Linux (apt):
sudo apt-get install bats

# macOS (homebrew):
brew install bats-core

# Or install locally to project:
git submodule add https://github.com/bats-core/bats-core.git tests/bats
git submodule add https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert

# Run tests:
bats tests/
```

## Testing Standards

1. **Test Isolation** - Each test runs in isolated environment
2. **Descriptive Names** - Test names clearly describe what's being tested  
3. **Given/When/Then** - Structure tests with clear setup/action/assertion
4. **Fast Execution** - Tests should run quickly (< 30 seconds total)
5. **Reliable** - Tests should be deterministic and not flaky

## Implementation Checklist

- [ ] Research and install bats framework
- [ ] Create test directory structure
- [ ] Implement basic test helpers
- [ ] Add first unit tests for user management
- [ ] Add integration tests for profile switching
- [ ] Create SSH testing utilities and tests
- [ ] Add migration testing
- [ ] Set up CI/CD integration
- [ ] Document testing procedures
- [ ] Train team on test writing and execution

## Success Metrics

- **Coverage**: Core functionality covered by automated tests
- **Speed**: Full test suite runs in < 30 seconds
- **Reliability**: Tests pass consistently across environments
- **Maintainability**: Tests are easy to read and update
- **CI Integration**: Tests run automatically on every change

## Status

Not Started

## Notes

- Start with core functionality tests before edge cases
- Use test-driven development for new features going forward
- Consider performance impact of test setup/teardown
- Mock external dependencies (GitHub API, SSH) where possible
- Keep tests readable and maintainable over comprehensive