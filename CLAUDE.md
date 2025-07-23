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

## Critical Bash Pitfalls & Shell Compatibility

### Variable Scope in Subshells
**CRITICAL**: `while ... done < file` creates subshells where local variables are NOT accessible

```bash
# ❌ WRONG - variables set in subshell don't propagate
local found=false
while IFS= read -r line; do
    if [[ "$line" == "target" ]]; then
        found=true  # This won't be visible outside the loop!
    fi
done < "$file"
[[ "$found" == true ]] && echo "Found"  # This will fail

# ✅ CORRECT - use process substitution
local found=false
while IFS= read -r line; do
    if [[ "$line" == "target" ]]; then
        found=true  # This WILL be visible outside the loop
    fi
done < <(cat "$file")
[[ "$found" == true ]] && echo "Found"  # This works
```

### Strict Mode Variable Access
**CRITICAL**: `set -euo pipefail` requires safe variable access patterns

```bash
# ❌ WRONG - fails with "unbound variable" in strict mode
if [[ -n "$current_git_email" ]]; then
    echo "Email: $current_git_email"
fi

# ✅ CORRECT - use parameter expansion with default
if [[ -n "${current_git_email:-}" ]]; then
    echo "Email: ${current_git_email:-}"
fi
```

### Fish Shell Compatibility
**CRITICAL**: Fish has read-only variables that bash scripts cannot modify

```bash
# ✅ CORRECT - protect against Fish environment conflicts
init_config() {
    # Protect against Fish shell variable conflicts
    if [[ -n "${FISH_VERSION:-}" ]]; then
        unset FISH_VERSION 2>/dev/null || true
        unset fish_greeting 2>/dev/null || true
        unset __fish_git_prompt_showdirtystate 2>/dev/null || true
    fi
    
    # ... rest of initialization
}
```

### Exit Code Propagation
**CRITICAL**: Command substitution and pipelines propagate exit codes

```bash
# ❌ WRONG - grep failure causes script exit in strict mode
user_host=$(grep "^${user}" "$file" | cut -d$'\t' -f5)

# ✅ CORRECT - handle command failures explicitly
user_host=$(grep "^${user}" "$file" 2>/dev/null | cut -d$'\t' -f5 || true)
```

### Debug Output Management
**CRITICAL**: Debug output can leak into production commands

```bash
# ❌ WRONG - debug output in production
echo "[DEBUG] Processing user: $username"

# ✅ CORRECT - conditional debug output
[[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] Processing user: $username" >&2
```

## Shell Compatibility Testing Checklist

### Before Any Shell-Related Changes:
1. **Test with strict mode**: `bash -euo pipefail script.sh`
2. **Test with Fish shell**: Install Fish and test wrapper functions
3. **Test variable scope**: Ensure no subshell variable access
4. **Test empty variables**: Use `${var:-}` syntax throughout
5. **Test exit codes**: Verify commands return expected codes
6. **Test debug output**: Ensure no debug leakage in production

### CI Environment Simulation:
```bash
# Local strict mode testing
bash -euo pipefail -c 'source ./script.sh && command'

# Fish environment testing  
fish -c 'source ./wrapper.fish && command'

# Variable unset testing
unset VARIABLE && bash -euo pipefail -c 'source ./script.sh && command'
```

## Post-Mortem Lessons (PR #27 Fish Test Failures)

### What Went Wrong:
1. **Variable Scope Issues**: Used `while ... done < file` which creates subshells
2. **Strict Mode Failures**: Unset variables caused "unbound variable" errors
3. **Fish Compatibility**: Read-only FISH_VERSION caused conflicts
4. **Reactive Debugging**: Fixed symptoms instead of root causes
5. **Multiple Partial Fixes**: 5+ commits for the same underlying issues

### Key Learnings:
1. **Reproduce CI failures locally** before attempting fixes
2. **Understand bash subshell rules** - process substitution vs pipes
3. **Test with Fish shell** and strict mode enabled
4. **Use systematic debugging** instead of trial-and-error
5. **One comprehensive fix** instead of multiple partial fixes

### Prevention Strategy:
- Always test shell compatibility locally before pushing
- Use the testing checklist above for all shell-related changes
- Understand the tools before using them (subshells, strict mode)
- Debug systematically with clear problem identification

### Shell Command Output Notes:
- **Always strip whitespace from `wc` output**: Use `wc -l < file | tr -d ' '`
  - `wc` outputs with leading spaces that can crash zsh in arithmetic comparisons
  - This pattern prevents `[[ 999 -gt "    1" ]]` type failures

## Git Branch Management & NPM Release Process

### Branch Strategy
```
main (production)     → What's published on npm
├── develop          → Integration branch for next release
├── feature/*        → New features (PR → develop)
├── fix/*           → Bug fixes (PR → develop)
├── release/v*      → Release prep (PR → main)
└── hotfix/*        → Emergency fixes (PR → main + develop)
```

### Release Process (ALWAYS follow this)
1. **Feature Development**: Work in `feature/*` or `fix/*` branches, PR to `develop`
2. **Release Prep**: Create `release/v*` from `develop`, final testing
3. **Publish**: Merge to `main`, then `npm publish` from main only
4. **Tag**: `git tag v*` after publishing
5. **Sync**: Merge `main` back to `develop`

### NPM Publishing Rules
- **ONLY publish from main branch**
- **ALWAYS tag releases** (`git tag v0.1.0`)
- **NEVER publish from feature branches**
- **Use semantic versioning**: MAJOR.MINOR.PATCH

### Quick Commands
```bash
# For releases (from release branch)
npm run release:patch  # 0.1.0 → 0.1.1
npm run release:minor  # 0.1.0 → 0.2.0
npm run release:major  # 0.1.0 → 1.0.0

# Check what would be published
npm run release:dry-run
```

See `RELEASE-CHECKLIST.md` for detailed release steps.