# Terminal Testing Plan - Real Shell Interaction Tests

## Overview

This plan implements real terminal testing using `expect` to catch shell-breaking bugs that our subshell tests miss. We'll test actual interactive shell behavior with a focused set of tests that verify shells survive error conditions.

## Why We Need This

Our recent `set -e` bug caused user shells to exit when commands failed. Despite having 206 tests, we missed this because:
- Subshell tests (`bash -c`) don't catch interactive shell state issues
- We weren't testing if shells survive after errors
- We had no tests for sourced script behavior

## Scope

### What We're Testing
- Shells survive when commands return non-zero exit codes
- Multiple errors in sequence don't corrupt shell state
- Shell remains functional after errors
- Sourcing behavior doesn't enable unwanted shell options

### What We're NOT Testing
- Command functionality (covered by existing tests)
- Output formatting (works fine in subshells)
- Performance (separate test suite)
- Every possible error permutation

## Technical Design

### Tool: Expect
- Industry standard for terminal automation
- Can verify prompts return after commands
- Detects difference between clean exit and crash
- Works with all shells we support

### Test Structure
```
tests/
  terminal/
    test_bash_terminal.exp     # Bash-specific tests
    test_zsh_terminal.exp      # Zsh-specific tests  
    test_terminal_runner.sh    # Simple test runner
    README.md                  # How to run and debug
```

## Implementation

### Core Test Script (bash example)

```expect
#!/usr/bin/env expect -f
# test_bash_terminal.exp - Test bash shell survives errors

set timeout 5
set script_path [lindex $argv 0]

# Start bash without rc files for clean environment
spawn bash --norc --noprofile
expect "$ "

# Source our script
send "source $script_path\r"
expect "$ "

# Test 1: Command with missing arguments
send "ghs remove\r"
expect {
    "Username or ID required" {
        expect "$ "
        puts "✓ Test 1 passed: Shell survived missing argument error"
    }
    eof {
        puts "✗ Test 1 FAILED: Shell crashed on missing argument"
        exit 1
    }
}

# Test 2: Invalid command
send "ghs invalid-command-xyz\r"
expect {
    "Unknown command" {
        expect "$ "
        puts "✓ Test 2 passed: Shell survived unknown command"
    }
    eof {
        puts "✗ Test 2 FAILED: Shell crashed on unknown command"
        exit 1
    }
}

# Test 3: Invalid user ID
send "ghs switch 999\r"
expect {
    -re "(not found|No users configured)" {
        expect "$ "
        puts "✓ Test 3 passed: Shell survived invalid user ID"
    }
    eof {
        puts "✗ Test 3 FAILED: Shell crashed on invalid user ID"
        exit 1
    }
}

# Test 4: Multiple errors in sequence
send "ghs remove\r"
expect "Username or ID required"
expect "$ "
send "ghs show nonexistent\r"
expect -re "(not found|Error)"
expect "$ "
puts "✓ Test 4 passed: Shell survived multiple errors"

# Test 5: Verify shell is still functional
send "echo 'Shell still works'\r"
expect {
    "Shell still works" {
        expect "$ "
        puts "✓ Test 5 passed: Shell remains functional after errors"
    }
    timeout {
        puts "✗ Test 5 FAILED: Shell not responding"
        exit 1
    }
}

# Test 6: Verify no strict mode when sourced
send "set -o | grep errexit\r"
expect {
    "errexit         off" {
        expect "$ "
        puts "✓ Test 6 passed: No strict mode in interactive shell"
    }
    "errexit         on" {
        puts "✗ Test 6 FAILED: Strict mode incorrectly enabled"
        exit 1
    }
}

# Clean exit
send "exit\r"
expect eof
puts "\nAll bash terminal tests passed!"
```

### Zsh-Specific Tests

```expect
#!/usr/bin/env expect -f
# test_zsh_terminal.exp - Test zsh shell survives errors

set timeout 5
set script_path [lindex $argv 0]

# Start zsh without rc files
spawn zsh -f
expect "% "

# Set a simple prompt for easier matching
send "PS1='> '\r"
expect "> "

# Source our script
send "source $script_path\r"
expect "> "

# Run same core tests as bash
# ... (similar tests but with zsh-specific prompt matching)

# Zsh-specific test: Verify array behavior
send "ghs users\r"
expect -re "(No users configured|Available users)"
expect "> "
puts "✓ Zsh array handling works correctly"

send "exit\r"
expect eof
puts "\nAll zsh terminal tests passed!"
```

### VS Code Integrated Terminal Tests

```expect
#!/usr/bin/env expect -f
# test_vscode_terminal.exp - Test VS Code specific shell behavior

set timeout 5
set script_path [lindex $argv 0]

# VS Code sets specific environment variables that can affect behavior
# Test with these variables set to catch VS Code-specific issues

# Test bash with VS Code environment
spawn env TERM_PROGRAM=vscode VSCODE_INJECTION=1 bash --norc --noprofile
expect "$ "

# VS Code often has special prompt handling
send "PS1='$ '\r"
expect "$ "

# Source with VS Code env vars present
send "source $script_path\r"
expect "$ "

# Test 1: VS Code terminal variables don't cause issues
send "ghs status\r"
expect {
    -re "(Current project|No users configured)" {
        expect "$ "
        puts "✓ VS Code Test 1 passed: Status works with VS Code env"
    }
    eof {
        puts "✗ VS Code Test 1 FAILED: Crashed with VS Code environment"
        exit 1
    }
}

# Test 2: Error handling in VS Code terminal
send "ghs remove\r"
expect "Username or ID required"
expect "$ "
puts "✓ VS Code Test 2 passed: Errors handled correctly"

# Test 3: VS Code's shell integration doesn't break our functions
send "type ghs\r"
expect "ghs is a function"
expect "$ "
puts "✓ VS Code Test 3 passed: Functions work in VS Code terminal"

# Clean exit
send "exit\r"
expect eof

# Also test with zsh (VS Code on macOS defaults to zsh)
spawn env TERM_PROGRAM=vscode VSCODE_INJECTION=1 zsh -f
expect "% "
send "PS1='> '\r"
expect "> "
send "source $script_path\r"
expect "> "
send "ghs remove\r"
expect "Username or ID required"
expect "> "
puts "✓ VS Code Test 4 passed: Zsh works in VS Code environment"
send "exit\r"
expect eof

puts "\nAll VS Code terminal tests passed!"
```

### Test Runner Script

```bash
#!/bin/bash
# test_terminal_runner.sh - Run all terminal tests

set -e

SCRIPT_PATH="$(cd "$(dirname "$0")/../.." && pwd)/gh-switcher.sh"
FAILED=0

echo "Running terminal tests..."
echo "========================"

# Check dependencies
if ! command -v expect >/dev/null; then
    echo "ERROR: 'expect' is required but not installed"
    echo "Install with: apt-get install expect (Linux) or brew install expect (macOS)"
    exit 1
fi

# Run bash tests
if command -v bash >/dev/null; then
    echo -e "\n→ Testing bash..."
    if expect tests/terminal/test_bash_terminal.exp "$SCRIPT_PATH"; then
        echo "✅ Bash tests passed"
    else
        echo "❌ Bash tests failed"
        FAILED=1
    fi
fi

# Run zsh tests
if command -v zsh >/dev/null; then
    echo -e "\n→ Testing zsh..."
    if expect tests/terminal/test_zsh_terminal.exp "$SCRIPT_PATH"; then
        echo "✅ Zsh tests passed"
    else
        echo "❌ Zsh tests failed"
        FAILED=1
    fi
fi

# Run VS Code terminal tests (always run since VS Code is common)
echo -e "\n→ Testing VS Code integrated terminal..."
if expect tests/terminal/test_vscode_terminal.exp "$SCRIPT_PATH"; then
    echo "✅ VS Code terminal tests passed"
else
    echo "❌ VS Code terminal tests failed"
    FAILED=1
fi

# Summary
echo -e "\n========================"
if [[ $FAILED -eq 0 ]]; then
    echo "✅ All terminal tests passed!"
else
    echo "❌ Some terminal tests failed"
    exit 1
fi
```

## CI Integration

### GitHub Actions Workflow

```yaml
name: Terminal Tests

on:
  push:
    branches: [main]
  pull_request:
    paths:
      - 'gh-switcher.sh'
      - 'tests/terminal/**'
      - '.github/workflows/terminal-tests.yml'

jobs:
  terminal-tests:
    name: Terminal Tests - ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install expect (Ubuntu)
        if: runner.os == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y expect
      
      - name: Install expect (macOS)
        if: runner.os == 'macOS'
        run: |
          brew install expect || true
      
      - name: Run terminal tests
        run: ./tests/terminal/test_terminal_runner.sh
      
      - name: Upload test output on failure
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: terminal-test-output-${{ matrix.os }}
          path: |
            tests/terminal/*.log
            tests/terminal/*.debug
```

## Debugging

### Running Locally
```bash
# Run all tests
./tests/terminal/test_terminal_runner.sh

# Run specific shell test
expect tests/terminal/test_bash_terminal.exp ./gh-switcher.sh

# Debug mode
expect -d tests/terminal/test_bash_terminal.exp ./gh-switcher.sh
```

### Common Issues

1. **Timeout failures**
   - Increase timeout in expect scripts
   - Check for slow shell initialization

2. **Prompt matching**
   - Ensure clean shell environment (--norc)
   - Use simple prompts for matching

3. **Platform differences**
   - macOS has old bash (3.2)
   - Different default prompts

## Maintenance

### When to Add Tests
- New shell-breaking bug is discovered
- User reports shell crashes
- New shell-specific behavior added

### When NOT to Add Tests  
- Feature already tested in subshells
- Hypothetical edge cases
- Performance or output formatting

### Test Guidelines
- Keep each test under 10 seconds
- Clear pass/fail output
- Test one concept per test
- Use descriptive test names

## Success Metrics

- Catches the `set -e` bug that sparked this effort
- Runs reliably in CI (no flaky tests)
- Completes in under 2 minutes
- Easy to understand failures

## Future Considerations

1. **Fish shell support** - Add if users report issues
2. **Windows Git Bash** - If expect becomes available
3. **Advanced scenarios** - Signal handling, job control

## Conclusion

This focused terminal testing approach gives us confidence that gh-switcher won't break user shells while avoiding the complexity of duplicating our entire test suite. We test what matters: shells survive errors and remain functional.