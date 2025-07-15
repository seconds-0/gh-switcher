# Essential E2E Tests Plan - 5 Critical User Journeys

## Overview
These 5 E2E tests focus on complete user workflows that CANNOT be properly tested without real shell execution. Each test represents a critical user journey.

## 1. Project Auto-Switching Journey

```bash
@test "e2e: project auto-switch: entering assigned directory switches user" {
    # This tests the killer feature - automatic user switching by directory
    
    # Setup
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Create two test directories
        mkdir -p ~/project1 ~/project2
        
        # Add two users
        ghs add user1 >/dev/null 2>&1
        ghs add user2 >/dev/null 2>&1
        
        # Assign different users to each project
        cd ~/project1
        ghs assign user1 >/dev/null 2>&1
        
        cd ~/project2  
        ghs assign user2 >/dev/null 2>&1
        
        # Test auto-switching
        cd ~/project1
        current=\$(ghs status 2>&1)
        if [[ \"\$current\" != *'user1'* ]]; then
            echo 'ERROR: Did not auto-switch to user1' >&2
            exit 1
        fi
        
        # Switch directories
        cd ~/project2
        current=\$(ghs status 2>&1)
        if [[ \"\$current\" != *'user2'* ]]; then
            echo 'ERROR: Did not auto-switch to user2' >&2
            exit 1
        fi
        
        # Verify git config also changed
        git_user=\$(git config user.name 2>/dev/null)
        if [[ \"\$git_user\" != *'user2'* ]]; then
            echo 'ERROR: Git config not updated on auto-switch' >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}
```

## 2. Git Identity Switching Journey

```bash
@test "e2e: git identity: switching users updates git config for commits" {
    # Tests that switching actually changes git identity for real commits
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Setup git repo
        mkdir -p ~/test-repo && cd ~/test-repo
        git init >/dev/null 2>&1
        
        # Add users with different identities
        ghs add alice >/dev/null 2>&1
        ghs add bob >/dev/null 2>&1
        
        # Create profiles (would normally be done via edit)
        mkdir -p ~/.config/gh-switcher/profiles
        echo 'alice|Alice Smith|alice@example.com||' > ~/.config/gh-switcher/profiles/alice
        echo 'bob|Bob Jones|bob@example.com||' > ~/.config/gh-switcher/profiles/bob
        
        # Switch to alice and make commit
        ghs switch alice >/dev/null 2>&1
        echo 'test' > file1.txt
        git add file1.txt
        git commit -m 'Alice commit' >/dev/null 2>&1
        
        # Verify commit author
        author=\$(git log -1 --format='%an <%ae>')
        if [[ \"\$author\" != 'Alice Smith <alice@example.com>' ]]; then
            echo \"ERROR: Wrong author: \$author\" >&2
            exit 1
        fi
        
        # Switch to bob and make another commit
        ghs switch bob >/dev/null 2>&1
        echo 'test2' > file2.txt
        git add file2.txt
        git commit -m 'Bob commit' >/dev/null 2>&1
        
        # Verify new commit author
        author=\$(git log -1 --format='%an <%ae>')
        if [[ \"\$author\" != 'Bob Jones <bob@example.com>' ]]; then
            echo \"ERROR: Wrong author: \$author\" >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}
```

## 3. SSH Authentication Flow Journey

```bash
@test "e2e: ssh auth flow: test-ssh validates and switches with SSH key" {
    # Tests SSH key validation and usage in actual commands
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Create test SSH key
        mkdir -p ~/.ssh
        ssh-keygen -t ed25519 -f ~/.ssh/test_key -N '' >/dev/null 2>&1
        
        # Add user with SSH key
        ghs add sshuser --ssh-key ~/.ssh/test_key >/dev/null 2>&1
        
        # Test SSH authentication (using our mock)
        output=\$(ghs test-ssh sshuser 2>&1)
        if [[ \$? -ne 0 ]]; then
            echo 'ERROR: SSH test failed' >&2
            exit 1
        fi
        
        # Switch to user and verify SSH command is configured
        ghs switch sshuser >/dev/null 2>&1
        
        # Check git SSH command is set
        ssh_cmd=\$(git config core.sshCommand)
        if [[ \"\$ssh_cmd\" != *'test_key'* ]]; then
            echo 'ERROR: Git SSH command not configured' >&2
            exit 1
        fi
        
        # In a real scenario, this would test actual git SSH operations
        # For E2E, we verify the configuration is correct
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}
```

## 4. Current User Addition Journey

```bash
@test "e2e: current user: add --current detects and configures authenticated user" {
    # Tests the onboarding flow for new users
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Mock gh auth status to return authenticated user
        export PATH=\"$TEST_PATH:\$PATH\"
        
        # Attempt to add current user
        output=\$(ghs add --current 2>&1)
        if [[ \$? -ne 0 ]]; then
            echo \"ERROR: Failed to add current user: \$output\" >&2
            exit 1
        fi
        
        # Verify user was added
        if [[ \"\$output\" != *'Added user: testuser'* ]]; then
            echo 'ERROR: Current user not detected correctly' >&2
            exit 1
        fi
        
        # Verify it's now the active user
        status=\$(ghs status 2>&1)
        if [[ \"\$status\" != *'testuser'* ]]; then
            echo 'ERROR: Current user not set as active' >&2
            exit 1
        fi
        
        # Verify profile was created with gh API data
        if [[ ! -f ~/.config/gh-switcher/profiles/testuser ]]; then
            echo 'ERROR: Profile not created for current user' >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}
```

## 5. Multi-Host Switching Journey

```bash
@test "e2e: multi-host: switching between github.com and enterprise users" {
    # Tests the enterprise use case of multiple GitHub instances
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Add user on github.com
        ghs add pubuser >/dev/null 2>&1
        
        # Add user on enterprise
        ghs add corpuser --host github.company.com >/dev/null 2>&1
        
        # Create profiles with host-specific settings
        mkdir -p ~/.config/gh-switcher/profiles
        echo 'pubuser|Public User|pubuser@users.noreply.github.com||github.com' > ~/.config/gh-switcher/profiles/pubuser
        echo 'corpuser|Corp User|corpuser@company.com||github.company.com' > ~/.config/gh-switcher/profiles/corpuser
        
        # Switch to public user
        ghs switch pubuser >/dev/null 2>&1
        
        # Verify we can test SSH against github.com
        output=\$(ghs test-ssh pubuser 2>&1)
        if [[ \"\$output\" == *'github.company.com'* ]]; then
            echo 'ERROR: Testing against wrong host' >&2
            exit 1
        fi
        
        # Switch to corporate user
        ghs switch corpuser >/dev/null 2>&1
        
        # Verify status shows enterprise host
        status=\$(ghs status 2>&1)
        if [[ \"\$status\" != *'github.company.com'* ]]; then
            echo 'ERROR: Enterprise host not shown in status' >&2
            exit 1
        fi
        
        # List users shows different hosts
        users=\$(ghs users 2>&1)
        if [[ \"\$users\" != *'github.company.com'* ]]; then
            echo 'ERROR: Host not shown in user list' >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}
```

## Why These 5 Tests Matter

1. **Project Auto-Switching**: Tests the most complex integration - directory change detection + automatic switching. Cannot be unit tested.

2. **Git Identity Switching**: Proves the core value prop - actual git commits with correct identity. Requires real git operations.

3. **SSH Authentication Flow**: Tests the full SSH setup including git config integration. Too complex for unit tests.

4. **Current User Addition**: Tests GitHub CLI integration and the onboarding experience. Requires shell environment.

5. **Multi-Host Switching**: Tests enterprise scenarios with multiple GitHub instances. Needs full environment setup.

## What We DON'T Test in E2E

- Input validation (unit tests)
- Error messages (unit tests)  
- File permissions (unit tests)
- Profile format parsing (unit tests)
- Edge cases (unit tests)
- Concurrent operations (too brittle)
- Network failures (too flaky)

## Implementation Priority

1. **Git Identity Switching** - Core functionality
2. **Project Auto-Switching** - Killer feature  
3. **Current User Addition** - Onboarding flow
4. **SSH Authentication Flow** - Complex but important
5. **Multi-Host Switching** - Enterprise users

Total: 5 focused, high-value E2E tests that prove gh-switcher works end-to-end.