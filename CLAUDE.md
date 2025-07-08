# CLAUDE.md - Build and Development Guide

## Project Overview
gh-switcher (`ghs`) is a lightning-fast, scriptable GitHub account switcher for developers with multiple GitHub identities. This is a Bash-based CLI tool focused exclusively on GitHub authentication context switching.

## Project Philosophy
- **CLI-first**: Commands must work perfectly in scripts and automation
- **Simple over complex**: Resist feature creep and over-engineering  
- **Automation-friendly**: Every feature supports non-interactive use
- **Project-aware**: Context-sensitive behavior based on git repository
- **Resist scope-creep**: GitHub account switching only, not generic git tools

### Implementation Guidelines
- **Function size**: <50 lines preferred for Bash functions
- **Test approach**: Unit tests + ≥1 higher layer (not exhaustive coverage)
- **Feature scope**: Minimal viable implementation first
- **Pattern matching**: Follow existing command patterns (cmd_switch, cmd_add, etc.)
- **Anti-patterns**: Avoid over-engineering, enterprise patterns, interactive TUIs

## Build Commands

### Essential Commands
```bash
# Lint the main script
npm run lint

# Run all tests
npm test

# Quick CI check (recommended before commits)
npm run ci-check

# Comprehensive local CI simulation
npm run ci-test

# Install globally (adds to ~/.zshrc)
npm run install-global

# Install guard hooks for account validation  
ghs guard install
```

### Development Workflow
```bash
# Before making changes
npm run ci-check

# After making changes
npm run lint
npm test

# MANDATORY before every commit (blocks commit if fails)
npm run lint
npm test

# Before committing
npm run ci-check

# Development convenience scripts (use ghs commands directly for user features)
npm run install-hook    # Development shortcut for: ghs guard install
npm run uninstall-hook  # Development shortcut for: ghs guard uninstall
```

## Testing (BATS-first)

### Framework & Structure
- **Primary**: bats-core 1.10+ (Vitest only with maintainer approval)
- **Layout**: `tests/unit/` (fast) and `tests/integration/` (CLI workflows)
- **Approach**: Unit tests + ≥1 higher layer per feature (not exhaustive coverage)
- **Performance**: <5s per BATS file on ubuntu-latest runners

### Test Environment
- Every BATS file loads `helpers/test_helper` and sets up isolated `$TEST_HOME`
- No network calls - mock GitHub API via stub
- Tag slow specs with `@slow` for nightly CI
- Structure helpers under `tests/helpers/` to avoid duplication

### Quality Standards
- **100% Test Execution**: Every detected test MUST execute
- **Zero Failures**: All tests must pass, no exceptions
- **Legitimate Skips Only**: Only skip for missing external dependencies (e.g., `gpg`)
- **Root Cause Fixes**: Never work around test failures

## Quality Standards

### Performance Requirements
- **CLI commands**: <100ms completion time
- **Guard hooks**: <300ms execution time
- **BATS files**: <5s per file on ubuntu-latest runners

### Code Quality
- **ShellCheck**: Compliance with exclusions: SC1091, SC2155, SC2181
- **Error handling**: All functions use the template format
- **Data safety**: Atomic file operations with temp files
- **Input validation**: Sanitize all user input
- **Base64**: Single-line output only (use `tr -d '\n'` or `base64 --wrap=0`)

### Data Safety Rules
- Use atomic file operations with temp files
- Profile format versioning for migrations
- Backup and recovery for corrupted profiles
- Base64 encoding for special characters in profiles

## Development Guidelines

### Always Rules
- **Data Safety**: Atomic operations, no data loss
- **Performance**: <100ms command completion (guard hooks <300ms execution)
- **Security**: SSH key validation, input sanitization
- **Non-Interactive**: All commands work in scripts/automation

### Anti-Patterns to Avoid
- **Over-engineering**: Complex solutions for simple problems
- **Function bloat**: >50 lines per Bash function
- **Test explosion**: Creating 3:1 test-to-code ratios
- **Enterprise patterns**: Applied to simple CLI tool
- **Interactive TUIs**: Main-menu interfaces
- **Scope creep**: Non-GitHub account features
- **Hard-coded paths**: Absolute paths or unscoped temp files

### Guard Hooks (Account Validation)
The project includes guard hooks that validate GitHub account and git profile before commits to prevent wrong-account commits.

#### Installation & Usage
```bash
# Install guard hooks for current repository
ghs guard install

# Check guard status and validation state
ghs guard status  

# Test validation without installing
ghs guard test

# Remove guard hooks
ghs guard uninstall
```

#### What it validates
- **GitHub account**: Checks if current GitHub user matches project assignment
- **Git config**: Ensures git name and email are configured
- **Profile matching**: Warns if git config doesn't match user profile

#### Normal Usage
```bash
# Setup protection for a project
ghs assign 2              # Assign user to project
ghs guard install         # Install validation hooks
git commit -m "message"   # Automatic validation

# Check status anytime
ghs guard status          # See protection status
ghs                       # Dashboard also shows guard status
```

#### Override when needed
```bash
# Bypass validation (not recommended)
GHS_SKIP_HOOK=1 git commit -m "your message"
```

#### Guard Hook Behavior
- **Fails commit** if GitHub account doesn't match project assignment
- **Fails commit** if git config is incomplete (missing name/email)
- **Warns but allows** if git config doesn't match profile
- **Skips validation** if GitHub CLI not authenticated
- **Provides guidance** on how to fix issues
- **Backs up existing hooks** during installation

### Code Patterns & Error Handling
All functions should follow this template pattern:

```bash
some_action() {
    local arg="$1"
    if [[ -z "$arg" ]]; then
        printf '❌ Missing argument\n' >&2
        return 1
    fi
    # …logic…
    printf '✅ Done\n'
}
```

**Key principles:**
- Quote every variable: `"$var"` – never bare expansions
- Prefer `[[ ]]` for conditionals; supply defaults `${VAR:-fallback}`
- Exit early with meaningful status codes
- Use feedback icons: ✅ success, ⚠️ warning, ❌ error, 💡 tip
- Name helpers with action verbs (`load_users`, `save_mapping`)
- Validate all inputs before processing
- Avoid `2>/dev/null` - use proper error handling

### Testing Requirements
- **New features**: Unit tests + ≥1 higher layer (not exhaustive coverage)
- **Test focus**: User workflows over implementation details
- **Realistic scenarios**: Avoid edge cases and over-engineering
- **ZERO TOLERANCE**: All tests must pass, no exceptions
- **Skips only**: For missing external dependencies (e.g., `gpg` binary)
- **Debugging**: Research → isolate → fix root cause (no workarounds)

### Test Debugging Methodology
When tests fail, follow this systematic approach:

1. **Research First**: Use documentation (BATS docs, official tool docs) to understand expected behavior before guessing
2. **Systematic Isolation**: Simplify failing test to minimal case, rebuild incrementally  
3. **Exact Output Matching**: Use BATS debug output to see actual vs expected:
   ```bash
   @test "example test" {
       run some_command
       echo "Debug: $output" >&3
       echo "Debug status: $status" >&3
       [ "$status" -eq 0 ]
   }
   ```
4. **Fix Root Cause**: Never work around test failures; fix the underlying issue completely

### Debug Output Usage
- Use `echo "Debug: $output" >&3` to see actual command output
- Use `echo "Debug status: $status" >&3` to see exit codes
- Use `echo "Debug lines: ${lines[*]}" >&3` to see output as array
- Run tests with `bats -t tests/unit/test_file.bats` for tap output

## File Structure

### Core Files
- `gh-switcher.sh` - Main executable (2000+ lines)
- `package.json` - npm configuration and scripts
- `tests/` - Comprehensive test suite with BATS framework

### Configuration Files
- `~/.gh-users` - List of usernames (one per line)
- `~/.gh-user-profiles` - Enhanced profile data (v3 format)
- `~/.gh-project-accounts` - Project to account mapping

### Documentation
- `Documentation/Plans/` - Workplan files with structured format
- `Documentation/Plans/archive/` - Completed workplans
- `docs/ROADMAP.md` - Project roadmap

## CI/CD Pipeline

### GitHub Actions
- Matrix testing: Ubuntu and macOS
- Node.js 18 support
- ShellCheck linting
- BATS testing framework
- Sequence: lint → test → build

### Pre-commit Checks
Use `npm run ci-check` before pushing to ensure:
- ShellCheck linting passes
- All tests pass in CI mode
- Bash compatibility verified
- Temporary files cleaned

## Workplan Format

Based on existing Documentation/Plans files, use this structure:

```markdown
# TASK-TYPE-Name - Brief Description

## Task ID
TASK-TYPE-Name

## Problem Statement
Clear description of the issue or feature need

## Proposed Solution
High-level approach to solving the problem

## Implementation Details
Technical details and approach

## Implementation Checklist
### Phase 1: Description
- [x] Completed item
- [ ] Pending item

### Phase 2: Description
- [ ] More items

## Testing Plan
1. Test scenario 1
2. Test scenario 2

## Status
Current status (Not Started/In Progress/Completed/Phases X-Y Completed)

## Notes
Additional context or considerations
```

### Task Management Process
1. Create workplan in `Documentation/Plans/`
2. Use clear task IDs (e.g., FEAT-DirectoryAutoSwitch, BUGFIX-ProfileReliability)
3. Track progress with checkboxes in Implementation Checklist
4. Move completed plans to `Documentation/Plans/archive/`
5. Update Status section as work progresses

## Performance Monitoring

### Performance Target
- End-to-end CLI commands should finish in **<100ms** on typical `ubuntu-latest` runner (cold start)
- Optimize for minimal external calls
- Measure command execution times during development

### Performance Testing
```bash
# Time a command
time ghs switch 1

# Profile multiple runs
for i in {1..5}; do
    echo "Run $i:"
    time ghs users
done

# Add timing to functions for debugging
debug_timer() {
    local start_time=$(date +%s%N)
    "$@"
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    echo "Debug: $* took ${duration}ms" >&2
}
```

### Performance Considerations
- Cache results where possible (git config detection, user profiles)
- Minimize `gh` API calls
- Use efficient file operations
- Test with large numbers of profiles
- Profile slow operations and optimize

## Security Considerations
- SSH key validation and integration
- GPG key support for commit signing
- Input validation for all user data
- No hardcoded paths or credentials
- Secure temporary file handling