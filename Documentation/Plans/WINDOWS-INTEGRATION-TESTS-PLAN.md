# Windows Integration Tests Plan

## Goal
Expand Windows CI from basic validation to meaningful integration tests that catch Windows-specific bugs without running the full test suite.

## Current State
- Windows CI only validates script syntax and sourcing
- Takes ~30 seconds (vs 5+ minutes for full suite)
- Doesn't test actual functionality

## Identified Risk Areas

### 1. Path Handling (HIGH RISK)
Windows users might use different path formats:
- `C:\Users\name\project` (Windows native)
- `C:/Users/name/project` (Windows forward slash)
- `/c/Users/name/project` (Git Bash)
- `/mnt/c/Users/name/project` (WSL)

**Test needed**: Project assignment with path normalization

### 2. Git Config Operations (MEDIUM RISK)
Special characters in names/emails:
- `CORP\username` (domain style)
- Unicode characters
- Paths in git config

**Test needed**: User switching with various name formats

### 3. SSH Key Paths (LOW RISK - Already handled)
- Permission validation works
- Path validation fixed
- Windows messages implemented

## Proposed Test Suite

### Windows-Specific Integration Tests (`tests/integration/test_windows.bats`)

```bash
@test "Windows: project assignment with different path formats" {
    # Skip on non-Windows
    [[ "$OSTYPE" != "msys" ]] && skip "Windows-specific test"
    
    # Test Unix-style path assignment
    cd /c/Users
    run ghs assign testuser
    assert_success
    
    # Test path retrieval
    run project_get_user_by_path "$PWD"
    assert_success
    assert_output "testuser"
}

@test "Windows: auto-switch with normalized paths" {
    [[ "$OSTYPE" != "msys" ]] && skip "Windows-specific test"
    
    # Assign to current directory
    run ghs assign testuser
    assert_success
    
    # Navigate away and back using different path style
    cd /
    cd C:/Users  # Windows style
    
    # Check if auto-switch would recognize it
    run ghs auto-switch test
    assert_output_contains "testuser"
}

@test "Windows: git config with special characters" {
    [[ "$OSTYPE" != "msys" ]] && skip "Windows-specific test"
    
    # Add user with backslash in name
    run ghs add winuser
    assert_success
    
    run ghs edit winuser --name "CORP\\john.smith" --email "john@corp.com"
    assert_success
    
    # Switch and verify
    run ghs switch winuser
    assert_success
    
    run git config user.name
    assert_output "CORP\\john.smith"
}

@test "Windows: SSH key validation with NTFS" {
    [[ "$OSTYPE" != "msys" ]] && skip "Windows-specific test"
    
    # Create key with wrong permissions
    mkdir -p "$HOME/.ssh"
    echo "fake key" > "$HOME/.ssh/test_key"
    chmod 644 "$HOME/.ssh/test_key"
    
    # Validate should succeed with warning
    run validate_ssh_key "$HOME/.ssh/test_key" true
    assert_success
    
    # Check for Windows-specific message
    run ghs show testuser
    assert_output_contains "Note: SSH key permissions are limited on Windows"
}
```

### CI Configuration Update

```yaml
# In .github/workflows/ci.yml
- name: Run Windows integration tests
  if: runner.os == 'Windows'
  run: |
    export OSTYPE="msys"
    export GHS_PERF_MULTIPLIER=3
    
    # Run only Windows-specific tests
    /usr/local/bin/bats tests/integration/test_windows.bats || {
      echo "Windows integration tests failed"
      exit 1
    }
```

## Implementation Steps

1. Create `tests/integration/test_windows.bats` with targeted tests
2. Update CI to run these specific tests on Windows
3. Keep the ~30 second runtime by only testing critical paths
4. Use test results to identify actual Windows bugs

## Success Criteria

- Windows CI catches path normalization issues
- Windows CI catches git config escaping issues  
- Runtime stays under 1 minute
- Tests are meaningful, not theatrical

## Estimated Time

- 2-3 hours to implement tests
- 1 hour to update CI and test
- Total: Half day

## Alternative: Status Quo

Keep minimal Windows validation and rely on user reports for Windows-specific bugs. This is acceptable given:
- Core functionality works
- We have Windows-specific code paths
- Community can report edge cases

But implementing these tests would catch issues before users hit them.