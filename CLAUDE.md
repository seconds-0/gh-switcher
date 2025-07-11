# gh-switcher (ghs) - Development Guide

## What It Is
Lightning-fast GitHub account switcher for developers with multiple identities. Switch GitHub contexts, manage SSH keys, and prevent wrong-account commits - all in <100ms.

## Core Features
- **Account switching**: `ghs switch <user>` - Switch GitHub CLI auth
- **SSH key management**: Auto-detect, validate, and fix permissions
- **Guard hooks**: Prevent commits with wrong GitHub account
- **Project assignment**: Auto-switch accounts by directory

## Essential Commands

### For Development
```bash
# Before making changes
npm run ci-check          # Full CI simulation

# During development  
npm run lint              # ShellCheck validation
npm test                  # Run all BATS tests

# Before committing (MANDATORY)
npm run lint && npm test  # Must both pass

# Install developer pre-commit hooks
npm run install-dev-hooks # Auto-run lint/tests before commits

# Install globally
npm run install-global    # Adds ghs to ~/.zshrc
```

### For Users
```bash
# Basic usage
ghs                       # Show current user and status
ghs switch <user>         # Switch GitHub account
ghs add <username>        # Add new GitHub user
ghs remove <username>     # Remove a user
ghs users                 # List all configured users

# Guard hooks (prevent wrong-account commits)
ghs guard install         # Install pre-commit validation
ghs guard status          # Check protection status
ghs guard test            # Test validation without committing
ghs guard uninstall       # Remove protection

# Project assignment
ghs assign <user>         # Assign user to current directory
```

## Development Principles

### Quality Gates (ALL must pass)
- ✅ Tests: 100% execution, zero failures
- ✅ ShellCheck: Clean (allowed: SC1091, SC2155, SC2181)  
- ✅ Functions: ~50 lines (guideline for clarity, not hard limit)
- ✅ Performance: <100ms commands, <300ms hooks
- ✅ Root causes: No workarounds or test modifications
- ✅ Plan adherence: Delivered what was promised

### Before Starting Any Task
Ask yourself:
1. Can I explain this in one sentence?
2. Will users notice and care?
3. Am I solving the actual problem?

### Red Flags - Stop and Rethink
- Changing tests instead of fixing code
- "It mostly works" or "good enough"
- Complex solution to simple problem  
- Can't debug the issue in 15 minutes

### When Tests Fail
**RULE**: Fix the code, never the test
1. First 15 min: Debug to understand why
2. Next 15 min: Fix the root cause
3. Can't fix in 30 min? Stop and document the blocker

### Before Declaring "Done"
**RULE**: Always verify against the plan
1. Review the implementation plan/checklist
2. Confirm all promised features are implemented
3. Run all tests that were promised
4. Check function line counts if refactoring
5. Ask: "Did I do what I said I would do?"

## Code Standards

### Shell Patterns
```bash
# Function template - ALL functions must follow this pattern
cmd_example() {
    local arg="${1:-}"
    [[ -z "$arg" ]] && { echo "❌ Missing argument" >&2; return 1; }
    
    # Core logic here
    
    echo "✅ Success"
    return 0
}

# Loading configuration safely
load_users() {
    [[ -f "$GH_USERS_FILE" ]] || return 0
    while IFS= read -r username || [[ -n "$username" ]]; do
        [[ -z "$username" ]] && continue
        echo "$username"
    done < "$GH_USERS_FILE"
}

# Profile parsing (v4 format)
parse_profile_line() {
    local line="$1"
    IFS='|' read -r username version name email ssh_key host <<< "$line"
    [[ "$version" == "v4" ]] || return 1
    echo "$username|$name|$email|$ssh_key|$host"
}

# Atomic file write pattern
save_to_file_atomic() {
    local file="$1"
    local content="$2"
    local temp_file
    temp_file=$(mktemp "${file}.XXXXXX") || return 1
    
    echo "$content" > "$temp_file" || { rm -f "$temp_file"; return 1; }
    mv -f "$temp_file" "$file" || { rm -f "$temp_file"; return 1; }
}

# Keep it simple - prefer shell builtins over complex logic
# Example: Use 'sort -u' instead of manual deduplication loops
```

### Error Handling
- Always quote variables: `"$var"`
- Use `[[ ]]` for conditionals
- Exit early with meaningful errors
- Icons: ✅ success, ⚠️ warning, ❌ error, 💡 tip
- NEVER use `A && B || C` pattern - use if/then/else

### File Safety
- Atomic operations with temp files
- Profile format: `username|v4|name|email|ssh_key|host`
- Validate input before processing
- Check file exists before reading: `[[ -f "$file" ]] || return 0`

## Testing

### Test Structure
```
tests/
├── unit/          # Fast, isolated function tests
├── integration/   # End-to-end workflows
└── helpers/       # Shared test utilities
```

### BATS Test Format
```bash
#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    setup_test_environment
    # Test-specific setup
}

teardown() {
    cleanup_test_environment
}

@test "descriptive test name" {
    # Arrange
    local input="test"
    
    # Act
    run cmd_example "$input"
    
    # Assert
    assert_success
    assert_output "✅ Success"
}

@test "error case handling" {
    run cmd_example ""
    assert_failure
    assert_output "❌ Missing argument"
}

# For debugging test failures
@test "debug example" {
    run some_command
    echo "Debug output: $output" >&3
    echo "Debug status: $status" >&3
    echo "Debug lines: ${lines[*]}" >&3
    assert_success
}
```

### Common Test Patterns
```bash
# Setup mock GitHub CLI
setup_mock_gh_user() {
    local username="$1"
    cat > "$TEST_HOME/gh" << EOF
#!/bin/bash
if [[ "\$1 \$2 \$3 \$4" == "api user -q .login" ]]; then
    echo "$username"
fi
EOF
    chmod +x "$TEST_HOME/gh"
    export PATH="$TEST_HOME:$PATH"
}

# Test file operations
create_test_file() {
    local file="$1"
    local content="$2"
    echo "$content" > "$file"
}

# Assert helpers (from test_helper)
assert_success      # status = 0
assert_failure      # status != 0
assert_output "text"  # exact match
assert_output_contains "partial"  # substring match
```

### Performance Requirements
- Commands: <100ms execution
- Guard hooks: <300ms execution  
- Test files: <5s per file on CI

## Common Issues

### Guard Hook Tests
- Test in isolated environment with proper PATH setup
- Mock `gh` CLI for predictable behavior
- Verify hook can find `ghs` after installation

### SSH Key Handling
- Auto-fix permissions (600) on detection
- Support absolute and tilde paths
- Validate key exists before setting

### Profile Format
- Only v4 format supported
- Preserve user data during updates
- Use pipe delimiter for extensibility

## File Structure
- `gh-switcher.sh` - Main script (~1000 lines)
- `~/.gh-users` - User list (one per line)
- `~/.gh-user-profiles` - Enhanced profiles (v4 format)
- `~/.gh-project-accounts` - Project→user mapping

## Development Philosophy

### User Delight First
Every line of code must earn its keep by delivering user value.

#### When to Add Code
✅ Features that spark joy (SSH auto-fix magic)  
✅ Features that prevent frustration (guard hooks)  
❌ Features that "might be useful someday"

#### When to Refactor
- Function approaching 50 lines? Split only if it improves clarity
- Can't understand code you wrote 3 months ago? Simplify
- Performance regression? Fix immediately

### Performance IS a Feature
- <50ms feels instant = delight
- <100ms feels fast = acceptable
- >100ms feels broken = fix it

### Anti-Patterns to Avoid
- Over-engineering simple problems
- Test-driven design (code-first, then test)
- Enterprise patterns in a CLI tool
- Interactive TUIs when CLI works fine

## Pull Request Process
```bash
# Create PR body
cat > /tmp/pr-body.md << 'EOF'
## Summary
- What changed

## Test Results
- All tests pass
- Performance validated

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF

# Create PR
gh pr create --title "feat: description" --body-file /tmp/pr-body.md

# Cleanup
rm /tmp/pr-body.md
```

## Development Wisdom
- Practice defensive programming when reasonable, but dont succumb to overengineering

## Design Principles for Error States

1. Explain what's wrong - "This file no longer exists at the configured location"
2. Show what we found - List all alternatives with helpful hints
3. Number the options - Makes it easy to reference
4. Provide exact commands - Copy-paste friendly
5. Explain consequences - "This prevents the error: ..."
6. Always offer escape hatch - "Or use HTTPS instead"

The extra verbosity in error states:
- Reduces user anxiety
- Prevents guesswork
- Makes support easier ("I chose option 2")
- Educates about the system

This matches how good CLIs handle errors - think git status after a merge conflict, where it becomes very explicit about your options.