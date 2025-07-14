# Directory Auto-Switch Implementation Plan

## Overview
Implement automatic GitHub account switching when changing directories, completing the project assignment feature by making it seamless and automatic.

## Goals
- Automatically switch GitHub accounts when entering a project directory
- Support parent directory inheritance (projects inherit from parent)
- Provide opt-out mechanism for safety
- Maintain <100ms performance requirement
- Zero surprises - predictable behavior

## Out of Scope (Explicitly NOT Doing)
1. **Global shell configuration changes** - We won't modify user's shell RC files automatically
2. **Complex directory patterns** - No regex/glob patterns for directory matching
3. **Recursive project scanning** - Won't scan all subdirectories looking for git repos
4. **Background processes** - No daemons or file watchers
5. **Cross-shell compatibility** - Focus on zsh/bash only, not fish/nushell/etc
6. **Symlink resolution** - Won't follow symlinks for project detection
7. **Network operations** - No remote config or cloud sync
8. **GUI/TUI components** - CLI only
9. **Automatic git config changes** - Only switch gh auth, not git config
10. **Smart detection based on remotes** - Won't analyze git remotes to guess account

## Detailed Implementation Plan

### Phase 1: Core Hook System

#### 1.1 Shell Integration Script
Create `shell-integration.sh` that users can source:
```bash
# Function called on directory change
__ghs_chpwd() {
    # Only run if ghs is available
    command -v ghs >/dev/null 2>&1 || return 0
    
    # Check if auto-switch is enabled
    [[ "${GHS_AUTO_SWITCH:-1}" == "0" ]] && return 0
    
    # Get current directory
    local current_dir="$PWD"
    
    # Check for direct assignment
    local assigned_user=$(ghs project get "$current_dir" 2>/dev/null)
    
    # If no direct assignment, check parent directories
    if [[ -z "$assigned_user" ]]; then
        local parent_dir="$current_dir"
        while [[ "$parent_dir" != "/" ]]; do
            parent_dir=$(dirname "$parent_dir")
            assigned_user=$(ghs project get "$parent_dir" 2>/dev/null)
            [[ -n "$assigned_user" ]] && break
        done
    fi
    
    # If we found an assignment, switch
    if [[ -n "$assigned_user" ]]; then
        # Get current user
        local current_user=$(ghs current -q 2>/dev/null)
        
        # Only switch if different
        if [[ "$current_user" != "$assigned_user" ]]; then
            ghs switch "$assigned_user" --quiet
            echo "🔄 Switched to GitHub account: $assigned_user"
        fi
    fi
}

# Hook into shells
if [[ -n "$ZSH_VERSION" ]]; then
    # Zsh: use chpwd hook
    autoload -U add-zsh-hook
    add-zsh-hook chpwd __ghs_chpwd
elif [[ -n "$BASH_VERSION" ]]; then
    # Bash: override cd
    cd() {
        builtin cd "$@"
        __ghs_chpwd
    }
fi
```

#### 1.2 New Commands for gh-switcher.sh

**`ghs project get <path>`** - Get assigned user for a path (already exists as internal function)
```bash
cmd_project_get() {
    local path="${1:-.}"
    local abs_path=$(cd "$path" 2>/dev/null && pwd)
    [[ -z "$abs_path" ]] && return 1
    
    local project_name=$(basename "$abs_path")
    local assigned_user=$(grep "^${project_name}=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d= -f2)
    
    [[ -n "$assigned_user" ]] && echo "$assigned_user"
}
```

**`ghs auto-switch [on|off|status]`** - Control auto-switching
```bash
cmd_auto_switch() {
    local action="${1:-status}"
    
    case "$action" in
        on)
            export GHS_AUTO_SWITCH=1
            echo "✅ Auto-switch enabled"
            ;;
        off)
            export GHS_AUTO_SWITCH=0
            echo "❌ Auto-switch disabled"
            ;;
        status)
            if [[ "${GHS_AUTO_SWITCH:-1}" == "1" ]]; then
                echo "✅ Auto-switch is enabled"
            else
                echo "❌ Auto-switch is disabled"
            fi
            ;;
        *)
            echo "Usage: ghs auto-switch [on|off|status]"
            return 1
            ;;
    esac
}
```

**`ghs current -q`** - Quiet mode for current user (for scripting)
```bash
# Modify existing cmd_status to support quiet flag
cmd_current() {
    local quiet=false
    [[ "$1" == "-q" || "$1" == "--quiet" ]] && quiet=true
    
    local current_user=$(gh api user -q .login 2>/dev/null || true)
    
    if [[ "$quiet" == true ]]; then
        [[ -n "$current_user" ]] && echo "$current_user"
    else
        # Existing status display code...
    fi
}
```

**`ghs switch --quiet`** - Add quiet mode to switch
```bash
# Modify cmd_switch to support --quiet flag
cmd_switch() {
    local quiet=false
    local user=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet|-q)
                quiet=true
                shift
                ;;
            *)
                user="$1"
                shift
                ;;
        esac
    done
    
    # ... existing switch logic ...
    
    # Only show output if not quiet
    if [[ "$quiet" != true ]]; then
        echo "✅ Switched to GitHub user: $username"
        # ... other output ...
    fi
}
```

### Phase 2: Parent Directory Inheritance

Modify project assignment to support inheritance:

**`ghs assign --inherit`** - Enable inheritance for current directory
```bash
# Store inheritance flag in project config
# Format: project_name=username:inherit
```

### Phase 3: Installation Experience

**`ghs install-hooks`** - Install shell integration
```bash
cmd_install_hooks() {
    local shell_rc=""
    
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    else
        echo "❌ Unsupported shell"
        return 1
    fi
    
    # Check if already installed
    if grep -q "__ghs_chpwd" "$shell_rc" 2>/dev/null; then
        echo "✅ Shell integration already installed"
        return 0
    fi
    
    # Add source line
    echo "" >> "$shell_rc"
    echo "# GitHub Switcher auto-switch integration" >> "$shell_rc"
    echo "source $SCRIPT_DIR/shell-integration.sh" >> "$shell_rc"
    
    echo "✅ Shell integration installed to $shell_rc"
    echo "💡 Restart your terminal or run: source $shell_rc"
}
```

## Test Plan

### Unit Tests

#### Test: Shell Integration Function
- Test `__ghs_chpwd` with various directory structures
- Test with GHS_AUTO_SWITCH=0 (disabled)
- Test with no ghs command available
- Test parent directory inheritance
- Test performance (<100ms requirement)

#### Test: Project Get Command
- Test with direct assignment
- Test with no assignment
- Test with invalid paths
- Test with symlinks (should not follow)

#### Test: Auto-Switch Command
- Test on/off/status actions
- Test environment variable persistence
- Test invalid actions

#### Test: Quiet Modes
- Test `ghs current -q` returns only username
- Test `ghs switch --quiet` produces no output
- Test error cases in quiet mode

### Integration Tests

#### Test: Full Auto-Switch Flow
```bash
@test "auto-switch changes user when entering assigned directory" {
    # Setup
    setup_test_project "work-project" "work-account"
    setup_test_project "personal-project" "personal-account"
    
    # Start in work project
    cd "$TEST_HOME/work-project"
    run __ghs_chpwd
    assert_success
    
    # Verify switched to work account
    run ghs current -q
    assert_output "work-account"
    
    # Change to personal project
    cd "$TEST_HOME/personal-project"
    run __ghs_chpwd
    assert_success
    
    # Verify switched to personal account
    run ghs current -q
    assert_output "personal-account"
}
```

#### Test: Parent Directory Inheritance
```bash
@test "auto-switch inherits from parent directory" {
    # Assign account to parent
    ghs assign work-account "$TEST_HOME/projects"
    
    # Create child project
    mkdir -p "$TEST_HOME/projects/child-project"
    cd "$TEST_HOME/projects/child-project"
    
    run __ghs_chpwd
    assert_success
    
    # Should inherit parent's assignment
    run ghs current -q
    assert_output "work-account"
}
```

#### Test: Opt-Out Mechanism
```bash
@test "auto-switch respects GHS_AUTO_SWITCH=0" {
    export GHS_AUTO_SWITCH=0
    
    setup_test_project "project" "account"
    cd "$TEST_HOME/project"
    
    run __ghs_chpwd
    assert_success
    
    # Should not switch
    run ghs current -q
    assert_not_output "account"
}
```

#### Test: Performance Requirements
```bash
@test "auto-switch completes within 100ms" {
    setup_test_project "project" "account"
    
    # Time the operation
    local start_time=$(date +%s%3N)
    cd "$TEST_HOME/project"
    __ghs_chpwd
    local end_time=$(date +%s%3N)
    
    local duration=$((end_time - start_time))
    assert [ $duration -lt 100 ]
}
```

### Manual Testing Checklist

1. **Installation Flow**
   - [ ] Run `ghs install-hooks` in fresh environment
   - [ ] Verify .zshrc/.bashrc updated correctly
   - [ ] Restart shell and verify hook is active

2. **Basic Auto-Switch**
   - [ ] Assign project: `ghs assign work`
   - [ ] Leave directory and return
   - [ ] Verify account switched automatically

3. **Parent Inheritance**
   - [ ] Assign parent directory
   - [ ] Enter subdirectory
   - [ ] Verify inheritance works

4. **Opt-Out**
   - [ ] Run `ghs auto-switch off`
   - [ ] Change directories
   - [ ] Verify no automatic switching

5. **Edge Cases**
   - [ ] Test with directories containing spaces
   - [ ] Test with very deep directory structures
   - [ ] Test with no GitHub CLI auth
   - [ ] Test with invalid project assignments

## Success Criteria

1. **Performance**: All operations complete in <100ms
2. **Reliability**: No errors during normal directory navigation
3. **Predictability**: Users understand when/why switching occurs
4. **Safety**: Easy to disable if causing issues
5. **Compatibility**: Works on macOS and Linux with bash/zsh

## Risks and Mitigations

1. **Risk**: Surprising users with unexpected switches
   - **Mitigation**: Clear output when switching occurs
   - **Mitigation**: Easy opt-out with `ghs auto-switch off`

2. **Risk**: Performance impact on every `cd`
   - **Mitigation**: Early returns for non-applicable cases
   - **Mitigation**: No network operations

3. **Risk**: Shell compatibility issues
   - **Mitigation**: Focused support for bash/zsh only
   - **Mitigation**: Graceful degradation if issues occur

4. **Risk**: Conflicts with other shell hooks
   - **Mitigation**: Unique function names with `__ghs_` prefix
   - **Mitigation**: Minimal shell modifications

## Implementation Order

1. Add quiet modes to existing commands (current, switch)
2. Add `project get` command
3. Create shell-integration.sh
4. Add `auto-switch` command
5. Add `install-hooks` command
6. Write comprehensive tests
7. Update documentation

## Documentation Updates

- README: Add "Auto-Switch" section with setup instructions
- CLAUDE.md: Add note about shell integration testing
- In-tool help: Update with new commands