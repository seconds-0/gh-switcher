# E2E Tests Plan - VS Code Terminal (Simplified)

## Goal
Ensure gh-switcher doesn't break in VS Code terminals. Period.

## What Actually Matters
1. gh-switcher doesn't crash with VS Code's environment variables
2. Basic commands work in VS Code terminals
3. Git operations work with VS Code's Git integration

## The Tests (Just 3)

### Test 1: Don't Crash on Unset Variables
```bash
@test "e2e: vscode: no crash with unset VS Code variables" {
    # This would have caught our production bug
    set -euo pipefail
    export TERM_PROGRAM=vscode
    
    # VS Code might set these, or might not
    unset VSCODE_SHELL_ENV_REPORTING 2>/dev/null || true
    unset VSCODE_CWD 2>/dev/null || true
    
    # Should not crash
    source "$script_path"
    ghs status
}
```

### Test 2: Basic Functionality
```bash
@test "e2e: vscode: basic commands work" {
    # Minimal VS Code environment
    export TERM_PROGRAM=vscode
    export VSCODE_GIT_IPC_HANDLE="/tmp/vscode-git"
    export VSCODE_INJECTION=1
    
    source "$script_path"
    
    # Core commands should work
    ghs add testuser
    ghs switch testuser
    ghs status | grep -q testuser
    ghs remove testuser
}
```

### Test 3: Git Integration Doesn't Break
```bash
@test "e2e: vscode: git operations work with VS Code env" {
    export TERM_PROGRAM=vscode
    export GIT_ASKPASS="$HOME/.vscode/extensions/git/askpass.sh"
    export VSCODE_GIT_ASKPASS_NODE="/usr/local/bin/node"
    
    source "$script_path"
    
    # Switch user and verify git config updated
    ghs add alice
    ghs switch alice
    
    # Git should still work
    cd $(mktemp -d)
    git init
    git config user.name | grep -q "alice"
}
```

## What We're NOT Testing
- VS Code shell integration features
- Remote development scenarios
- VS Code extensions
- Command decorations
- Performance impact
- Different VS Code versions
- PowerShell in VS Code (that's PowerShell's problem)

## Implementation
1. Add these 3 tests to our E2E suite
2. Run them in CI
3. Done

## Success Criteria
- Tests pass
- No maintenance burden
- Would have caught our production bug

That's it. No 40-test suite. No complex mocking. Just verify we don't break.