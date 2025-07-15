#!/usr/bin/env bats

# Essential E2E Tests - 5 Critical User Journeys
# Tests complete workflows that require real shell execution

load '../helpers/test_helper'
load 'helpers/e2e_helper'

setup() {
    setup_e2e_test_env
    create_mock_gh
    create_test_ssh_keys
}

teardown() {
    cleanup_e2e_test_env
}

# 1. Project Auto-Switching Journey
@test "e2e: project auto-switch: entering assigned directory switches user" {
    # This tests the killer feature - automatic user switching by directory
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Create test directories with unique names to avoid conflicts
        test_dir1=\$(mktemp -d -t 'ghs-test-project1.XXXXXX')
        test_dir2=\$(mktemp -d -t 'ghs-test-project2.XXXXXX')
        
        # Add two users
        ghs add user1 >/dev/null 2>&1
        ghs add user2 >/dev/null 2>&1
        
        # Create profiles for users (tab-separated format in single file)
        printf 'user1\tUser One\tuser1@example.com\t\tgithub.com\n' > ~/.gh-user-profiles
        printf 'user2\tUser Two\tuser2@example.com\t\tgithub.com\n' >> ~/.gh-user-profiles
        
        # Assign different users to each project
        cd \"\$test_dir1\"
        ghs assign user1 >/dev/null 2>&1
        
        cd \"\$test_dir2\"
        ghs assign user2 >/dev/null 2>&1
        
        # Enable auto-switch
        ghs auto-switch enable >/dev/null 2>&1
        
        # Test assignment was recorded correctly
        cd \"\$test_dir1\"
        # Manually trigger auto-switch check since shell hook isn't installed
        ghs auto-switch check >/dev/null 2>&1
        current=\$(ghs status 2>&1)
        if [[ \"\$current\" != *'user1'* ]]; then
            echo \"ERROR: Did not switch to user1 in project1\" >&2
            echo \"Status output: \$current\" >&2
            exit 1
        fi
        
        # Switch directories and check again
        cd \"\$test_dir2\"
        ghs auto-switch check >/dev/null 2>&1
        current=\$(ghs status 2>&1)
        if [[ \"\$current\" != *'user2'* ]]; then
            echo \"ERROR: Did not switch to user2 in project2\" >&2
            echo \"Status output: \$current\" >&2
            exit 1
        fi
        
        # Clean up
        rm -rf \"\$test_dir1\" \"\$test_dir2\"
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}

# 2. Git Identity Switching Journey
@test "e2e: git identity: switching users updates git config for commits" {
    # Tests that switching actually changes git identity for real commits
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Setup git repo with unique name
        test_repo=\$(mktemp -d -t 'ghs-test-repo.XXXXXX')
        cd \"\$test_repo\"
        git init >/dev/null 2>&1
        
        # Add users with different identities
        ghs add alice >/dev/null 2>&1
        ghs add bob >/dev/null 2>&1
        
        # Create profiles (tab-separated format in single file)
        printf 'alice\tAlice Smith\talice@example.com\t\tgithub.com\n' > ~/.gh-user-profiles
        printf 'bob\tBob Jones\tbob@example.com\t\tgithub.com\n' >> ~/.gh-user-profiles
        
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
        
        # Clean up
        rm -rf \"\$test_repo\"
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}

# 3. SSH Authentication Flow Journey
@test "e2e: ssh auth flow: test-ssh validates and switches with SSH key" {
    # Tests SSH key validation and usage in actual commands
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Create test SSH key
        mkdir -p ~/.ssh
        ssh-keygen -t ed25519 -f ~/.ssh/test_key -N '' >/dev/null 2>&1
        
        # Add user with SSH key (pipe yes for non-interactive)
        echo 'y' | ghs add sshuser --ssh-key ~/.ssh/test_key >/dev/null 2>&1
        
        # Switch to user and verify SSH command is configured
        ghs switch sshuser >/dev/null 2>&1
        
        # Check git SSH command is set in a git repo
        mkdir -p ~/test-repo && cd ~/test-repo
        git init >/dev/null 2>&1
        
        # Apply profile to get SSH config
        ghs switch sshuser >/dev/null 2>&1
        
        ssh_cmd=\$(git config core.sshCommand)
        if [[ \"\$ssh_cmd\" != *'test_key'* ]]; then
            echo \"ERROR: Git SSH command not configured. Got: \$ssh_cmd\" >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}

# 4. Current User Addition Journey
@test "e2e: current user: add --current detects and configures authenticated user" {
    # Tests the onboarding flow for new users
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Add current user (our mock returns 'testuser')
        output=\$(ghs add current 2>&1)
        
        # Just verify user was added
        if ! ghs users | grep -q 'testuser'; then
            echo 'ERROR: Current user not added' >&2
            exit 1
        fi
        
        echo 'SUCCESS'
    "
    
    assert_success
    assert_output_contains "SUCCESS"
}

# 5. Multi-Host Switching Journey
@test "e2e: multi-host: switching between github.com and enterprise users" {
    # Tests the enterprise use case of multiple GitHub instances
    
    local script_path="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/gh-switcher.sh"
    
    run bash -c "
        source '$script_path'
        
        # Add user on github.com
        ghs add pubuser >/dev/null 2>&1
        
        # Add user on enterprise
        ghs add corpuser --host github.company.com >/dev/null 2>&1
        
        # Create profiles with host-specific settings (tab-separated format)
        printf 'pubuser\tPublic User\tpubuser@users.noreply.github.com\t\tgithub.com\n' > ~/.gh-user-profiles
        printf 'corpuser\tCorp User\tcorpuser@company.com\t\tgithub.company.com\n' >> ~/.gh-user-profiles
        
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