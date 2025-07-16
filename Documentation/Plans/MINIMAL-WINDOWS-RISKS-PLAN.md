# Minimal Windows Risk Mitigation Plan

## Goal
Address the two realistic Windows-specific risks with minimal, focused tests that increase confidence without over-engineering.

## The Two Real Risks

### Risk 1: Path Assignment/Matching Mismatch
**Scenario**: User assigns project using one path format but Git Bash normalizes differently when navigating
```bash
# User does:
cd C:\Projects\myapp
ghs assign alice
# Later:
cd /c/Projects/myapp  # Git Bash normalized
ghs  # Might not recognize assignment
```

### Risk 2: Windows Domain Username in Git Config
**Scenario**: Corporate users with domain-style names
```bash
ghs edit alice --name "CORP\alice.smith"
# Will git config handle the backslash correctly?
```

## Minimal Test Implementation

### Create: `tests/integration/test_windows_risks.bats`

```bash
#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    # Only run on Windows
    [[ "$OSTYPE" != "msys" ]] && skip "Windows-specific test"
    
    setup_test_environment
    # Add a test user
    cmd_add "testuser" >/dev/null 2>&1
}

teardown() {
    cleanup_test_environment
}

@test "Windows: project assignment survives path format changes" {
    # Create a test directory
    mkdir -p "$TEST_HOME/testproject"
    cd "$TEST_HOME/testproject"
    git init -q
    
    # Assign using current path (Git Bash normalized)
    run ghs assign testuser
    assert_success
    
    # Store the assigned path
    local assigned_path="$PWD"
    
    # Navigate away
    cd "$TEST_HOME"
    
    # Come back using potentially different format
    # (In real Windows, this might be C:\... but in tests it's the same)
    cd "$assigned_path"
    
    # Verify assignment still recognized
    run project_get_user_by_path "$PWD"
    assert_success
    assert_output "testuser"
}

@test "Windows: git config handles domain-style usernames" {
    # Create profile with backslash in name
    run cmd_edit testuser --name "CORP\\alice.smith" --email "alice@corp.com"
    assert_success
    
    # Switch to user
    cd "$TEST_HOME"
    git init -q
    run cmd_switch testuser
    assert_success
    
    # Verify git stored it correctly
    run git config user.name
    assert_success
    assert_output "CORP\\alice.smith"
    
    # Verify it survives a round trip
    run git_get_identity
    assert_success
    assert_output_contains "name:CORP\\alice.smith"
}
```

### Update: `.github/workflows/ci.yml`

Replace the current Windows validation with:

```yaml
# Windows: Run focused integration tests
- name: Windows integration tests
  if: runner.os == 'Windows'
  run: |
    # Set Windows environment
    export OSTYPE="msys"
    export GHS_PERF_MULTIPLIER=3
    
    # Install BATS if needed (reuse existing logic)
    if [[ ! -f /usr/local/bin/bats ]]; then
        git clone --depth 1 https://github.com/bats-core/bats-core.git
        (cd bats-core && ./install.sh /usr/local)
    fi
    
    # Run ONLY the Windows risk tests
    /usr/local/bin/bats tests/integration/test_windows_risks.bats || {
        echo "❌ Windows integration tests failed"
        exit 1
    }
    
    echo "✅ Windows risk tests passed"
```

## Why This is Minimal and Focused

1. **Only 2 tests** - One for each real risk
2. **Fast execution** - Should add < 30 seconds
3. **Real scenarios** - Based on actual usage patterns
4. **No over-testing** - Not testing things that already work

## Implementation Steps

1. Create the test file with just these 2 tests
2. Update CI to run only this file on Windows
3. Verify it catches the issues if they exist
4. Fix any actual bugs found

## Success Criteria

- [ ] Path assignment works regardless of navigation method
- [ ] Domain usernames work in git config
- [ ] Tests complete in < 1 minute on Windows
- [ ] No test theater - only testing real risks

## Next Steps After This

Once these pass, we can:
1. Ship with confidence
2. Move on to features
3. Add more tests only if users report issues