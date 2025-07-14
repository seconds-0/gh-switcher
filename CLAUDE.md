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
- **Reverting changes due to syntax/technical issues without solving the core problem**
- **Claiming completion when hitting technical roadblocks**
- **Marking tasks complete while ignoring the original requirements**

### When Tests Fail
**RULE**: Fix the code, never the test
1. First 15 min: Debug to understand why
2. Next 15 min: Fix the root cause
3. Can't fix in 30 min? Stop and document the blocker

### When You Hit Technical Issues (Syntax Errors, Test Failures, etc.)
**RULE**: Technical problems don't change the requirements
1. **First 15 min**: Debug to understand the issue  
2. **Next 15 min**: Fix the technical problem (syntax, imports, etc.)
3. **If still blocked**: Ask for help or suggest alternative approaches
4. **NEVER**: Revert changes and claim the task is complete
5. **NEVER**: Mark requirements as "done" when technical issues prevented implementation

**Remember**: Syntax errors, test framework issues, and tooling problems are fixable - they don't excuse not meeting the requirements.

### Before Declaring "Done"
**RULE**: Always verify against the plan
1. Review the implementation plan/checklist
2. Confirm all promised features are implemented
3. Run all tests that were promised
4. Check function line counts if refactoring
5. **Re-read the original requirements and verify each one is met**
6. **If you reverted changes due to technical issues, the task is NOT complete**
7. Ask: "Did I do what I said I would do?"

## Development Memories

### Testing and Debugging Philosophy
- **BATS Syntax errors are normal debugging, not project blockers. Fix the syntax, don't abandon the approach. Look up documentation with web search if stuck**
- **BATS test numbering gaps**: When tests fail to execute (0 of N), check for missing helper loads first before changing test logic

### Implementation Verification
- Always check the implementation versus the plan. If it doesnt match the plan, it is wrong. If the plan needs to change, ask the users permission.

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