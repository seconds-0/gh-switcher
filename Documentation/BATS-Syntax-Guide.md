# BATS Syntax Guide - Complete Reference

## Overview
BATS (Bash Automated Testing System) is a TAP-compliant testing framework for Bash. This guide covers all syntax patterns needed for gh-switcher testing.

## Basic Test Structure

### @test Syntax
```bash
@test "descriptive test name" {
    # Test code here
    run some_command
    assert_success
}
```

**Key Rules:**
- Test name MUST be quoted (double quotes preferred)
- Opening brace `{` MUST be on same line as `@test`
- Closing brace `}` MUST be on its own line
- No semicolons needed before braces

### Common Syntax Errors to Avoid
```bash
# ❌ WRONG - brace on new line
@test "test name"
{
    # code
}

# ❌ WRONG - missing quotes
@test test name {
    # code
}

# ✅ CORRECT
@test "test name" {
    # code
}
```

## The `run` Command

### Basic Usage
```bash
run command arg1 arg2
```

### With Status Expectations
```bash
run -0 command  # Expect success (status 0)
run -1 command  # Expect failure (status 1)
run -127 command  # Expect specific status
```

### Capturing Output
```bash
run command
echo "Status: $status"        # Exit code
echo "Output: $output"        # Full output
echo "First line: ${lines[0]}" # First line only
```

### Complex Commands
```bash
# Command with pipes
run bash -c "echo 'test' | grep 'test'"

# Command with redirection
run bash -c "echo 'test' > /tmp/file"

# Command with environment variables
run env VAR=value command

# Command in specific directory
run bash -c "cd /path && command"
```

## Assertion Functions

### Status Assertions
```bash
assert_success          # Status must be 0
assert_failure          # Status must be non-zero
assert_failure 1        # Status must be specific code
```

### Output Assertions
```bash
# Exact match
assert_output "expected text"

# Partial match
assert_output --partial "part of text"
assert_output -p "part of text"

# Regex match
assert_output --regexp "^pattern$"
assert_output -e "^pattern$"

# Empty output
assert_output ""
```

### Line Assertions
```bash
# Search all lines for content
assert_line "expected line"

# Check specific line by index (0-based)
assert_line --index 0 "first line"
assert_line -n 1 "second line"

# Partial line match
assert_line --partial "part of line"
assert_line -p "part of line"

# Regex line match
assert_line --regexp "^pattern"
assert_line -e "^pattern"
```

### Negative Assertions
```bash
refute_output "should not appear"
refute_output --partial "should not appear"
refute_line "should not be a line"
```

### Custom Assertions
```bash
# Using standard bash tests
[[ "$status" -eq 0 ]]
[[ "$output" == "expected" ]]
[[ "${lines[0]}" =~ ^Error: ]]
```

## Setup and Teardown

### Per-Test Setup/Teardown
```bash
setup() {
    # Run before EACH test
    export TEST_VAR="value"
    mkdir -p "$BATS_TEST_TMPDIR/test"
}

teardown() {
    # Run after EACH test
    rm -rf "$BATS_TEST_TMPDIR/test"
}
```

### Per-File Setup/Teardown
```bash
setup_file() {
    # Run ONCE before all tests in file
    export GLOBAL_VAR="value"
}

teardown_file() {
    # Run ONCE after all tests in file
    cleanup_global_resources
}
```

## Loading External Files

### Load Helper Files
```bash
load 'helpers/test_helper'
load '../helpers/common'
```

### Load Assertion Libraries
```bash
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
```

## Variables and Paths

### BATS Built-in Variables
```bash
$BATS_TEST_FILENAME     # Current test file path
$BATS_TEST_DIRNAME      # Directory of current test file
$BATS_TEST_NAME         # Current test name
$BATS_TEST_TMPDIR       # Temporary directory for test
$BATS_FILE_TMPDIR       # Temporary directory for file
```

### Common Path Patterns
```bash
# Script being tested
SCRIPT_PATH="$BATS_TEST_DIRNAME/../../gh-switcher.sh"

# Test data directory
TEST_DATA="$BATS_TEST_DIRNAME/data"

# Relative to test file
HELPER_PATH="$BATS_TEST_DIRNAME/../helpers/test_helper"
```

## Conditional Tests and Skipping

### Skip Tests
```bash
@test "optional test" {
    skip "Feature not implemented yet"
    # Test code
}

@test "conditional test" {
    if [[ ! -f /required/file ]]; then
        skip "Required file not found"
    fi
    # Test code
}
```

### Conditional Logic
```bash
@test "platform specific test" {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        skip "Linux only test"
    fi
    # Test code
}
```

## Common Patterns for gh-switcher

### Test Git Commands
```bash
@test "git commit should fail" {
    # Setup
    cd "$TEST_GIT_REPO"
    echo "test" > file.txt
    git add file.txt
    
    # Test actual git commit
    run git commit -m "test message"
    assert_failure
    assert_output_contains "Account mismatch"
}
```

### Test File Operations
```bash
@test "file should be created" {
    run bash "$SCRIPT_PATH" add testuser
    assert_success
    
    # Verify file was created
    [[ -f "$TEST_CONFIG_FILE" ]]
    
    # Verify content
    run cat "$TEST_CONFIG_FILE"
    assert_output_contains "testuser"
}
```

### Test Environment Variables
```bash
@test "environment variable affects behavior" {
    # Set environment
    export GHS_SKIP_HOOK=1
    
    # Test behavior
    run bash "$SCRIPT_PATH" guard test
    assert_success
}
```

### Mock External Commands
```bash
@test "mock gh command" {
    # Create mock gh command
    cat > "$TEST_HOME/gh" << 'EOF'
#!/bin/bash
if [[ "$1 $2" == "auth status" ]]; then
    echo "✓ Logged in to github.com as testuser"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
    
    # Test with mock
    run bash "$SCRIPT_PATH" switch testuser
    assert_success
}
```

## Debug and Troubleshooting

### Debug Output
```bash
@test "debug example" {
    run some_command
    
    # Debug output (visible with -t flag)
    echo "DEBUG: Status = $status" >&3
    echo "DEBUG: Output = $output" >&3
    echo "DEBUG: Lines = ${lines[*]}" >&3
    
    assert_success
}
```

### Common Debug Commands
```bash
# Print all variables
set | grep BATS >&3

# Print working directory
pwd >&3

# Print PATH
echo "PATH: $PATH" >&3

# Print file contents
cat "$file" >&3
```

## Error Handling

### Robust Test Patterns
```bash
@test "robust test pattern" {
    # Ensure clean state
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
    
    # Setup
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Test
    run command_under_test
    
    # Assertions
    assert_success
    assert_output_contains "expected"
    
    # Verify side effects
    [[ -f "expected_file" ]]
}
```

### Handle Command Failures
```bash
@test "handle command failures" {
    run command_that_might_fail
    
    # Check specific failure
    if [[ "$status" -eq 1 ]]; then
        assert_output_contains "specific error"
    elif [[ "$status" -eq 2 ]]; then
        assert_output_contains "different error"
    else
        # Unexpected status
        echo "Unexpected status: $status, output: $output" >&3
        return 1
    fi
}
```

## Best Practices

### 1. Use Descriptive Test Names
```bash
# ✅ Good
@test "guard hook prevents commit when GitHub user doesn't match project assignment"

# ❌ Bad
@test "test guard hook"
```

### 2. Test One Thing Per Test
```bash
# ✅ Good - focused test
@test "add command creates user in config file" {
    run bash "$SCRIPT_PATH" add testuser
    assert_success
    
    run grep "testuser" "$CONFIG_FILE"
    assert_success
}

# ❌ Bad - testing multiple things
@test "add and remove work" {
    # Tests both add and remove
}
```

### 3. Use Setup/Teardown for Common Code
```bash
setup() {
    # Common setup for all tests
    export TEST_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
    mkdir -p "$TEST_CONFIG_DIR"
}

teardown() {
    # Common cleanup
    rm -rf "$TEST_CONFIG_DIR"
}
```

### 4. Make Tests Independent
```bash
# ✅ Good - each test sets up its own state
@test "first test" {
    echo "data" > "$TEST_FILE"
    run process_file "$TEST_FILE"
    assert_success
}

@test "second test" {
    echo "other data" > "$TEST_FILE"
    run process_file "$TEST_FILE"
    assert_success
}
```

## Syntax Troubleshooting

### Common Syntax Errors and Fixes

#### 1. Brace Placement
```bash
# ❌ Error: syntax error near unexpected token '{'
@test "test name"
{
    # code
}

# ✅ Fix: Brace on same line
@test "test name" {
    # code
}
```

#### 2. Missing Quotes
```bash
# ❌ Error: command not found
@test test name {
    # code
}

# ✅ Fix: Quote test name
@test "test name" {
    # code
}
```

#### 3. Incorrect Function Syntax
```bash
# ❌ Error: syntax error
function setup() {
    # code
}

# ✅ Fix: Use simple function syntax
setup() {
    # code
}
```

#### 4. Assertion Syntax
```bash
# ❌ Error: command not found
assert_output_contains "text"

# ✅ Fix: Ensure bats-assert is loaded
load 'test_helper/bats-assert/load'
assert_output_contains "text"
```

## Running Tests

### Basic Test Execution
```bash
# Run single test file
bats test_file.bats

# Run all tests in directory
bats tests/

# Run with verbose output
bats -t test_file.bats

# Run specific test by name
bats -f "test name pattern" test_file.bats
```

### Debug Mode
```bash
# Show debug output (>&3)
bats -t test_file.bats

# Show all output
bats --verbose-run test_file.bats
```

This guide covers all BATS syntax patterns used in gh-switcher testing. Keep it as a reference for avoiding syntax errors and writing robust tests.