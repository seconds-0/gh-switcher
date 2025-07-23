# Homebrew Standalone Detection Plan

## Overview
When gh-switcher is installed via Homebrew or npm globally, it runs as a standalone executable rather than being sourced into the shell. This limits certain features that require shell integration. This plan outlines how to detect the installation method and gracefully handle unavailable features.

## Problem Statement
- Homebrew and npm global installs create a subprocess that cannot modify the parent shell environment
- Features like `auto-switch` (cd hook) and `fish-setup` require shell integration
- Users may be confused when these features don't work with standalone installation
- Current implementation shows all commands regardless of installation method
- No clear documentation about feature limitations with different installation methods

## Solution Overview
1. Detect whether gh-switcher is running as standalone (Homebrew/npm) or sourced
2. Hide unavailable commands from help text when running standalone
3. Provide helpful error messages with specific remediation steps
4. Show installation type in status and doctor commands
5. Guide users to manual installation for full features
6. Update all documentation to clearly communicate limitations
7. Add visual indicators for command availability

## Implementation Details

### 1. Detection Function
Add after configuration section (~line 100 in gh-switcher.sh):

```bash
# Check if running as standalone executable (not sourced)
is_standalone() {
    # Bash: direct execution check
    if [[ -n "${BASH_VERSION:-}" ]]; then
        [[ "${BASH_SOURCE[0]}" == "${0}" ]] && return 0
        return 1
    fi
    
    # Zsh: use eval context consistently with rest of codebase
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # When sourced, zsh_eval_context contains "file"
        # When executed, it contains "toplevel" or is empty
        [[ ! " ${zsh_eval_context[*]:-} " =~ " file " ]] && return 0
        return 1
    fi
    
    return 1
}

# Get installation method for user-friendly messages
get_installation_method() {
    if ! is_standalone; then
        echo "shell-sourced"
        return
    fi
    
    local script_path="$(readlink -f "$0" 2>/dev/null || echo "$0")"
    if [[ "$script_path" =~ homebrew ]]; then
        echo "Homebrew"
    elif command -v npm >/dev/null 2>&1 && npm list -g gh-switcher >/dev/null 2>&1; then
        echo "npm-global"
    else
        echo "standalone"
    fi
}
```

### 2. Commands Affected

#### Commands that REQUIRE shell integration (will be hidden/blocked):
- `auto-switch` - Needs to hook into shell's cd command
- `fish-setup` - Only relevant for sourced installations

#### Commands that work in BOTH modes:
- All other commands (add, remove, switch, assign, users, show, edit, test-ssh, status, doctor, guard, help)

### 3. Help Command Modifications

Update `cmd_help()` to conditionally show commands:

```bash
cmd_help() {
    cat << 'EOF'
🎯 GitHub Project Switcher (ghs)

USAGE:
  ghs <command> [options]

COMMANDS:
  add <user|current>  Add GitHub account ('current' auto-detects from gh CLI)
  remove <user>       Remove account by name or number
  switch <user>       Change active git config to different account
  assign <user>       Auto-switch to this account in current directory
  assign --list       List all directory assignments
  assign --remove     Remove assignment for current or specified path
  assign --clean      Clean up non-existent paths
  users               List all accounts with SSH/HTTPS status
  show <user>         View account details and diagnose issues
  edit <user>         Update email, SSH key, or host settings
  test-ssh [<user>]   Verify SSH key works with GitHub
  status              Show current account and project state (default)
  doctor              Show diagnostics for troubleshooting
  guard               Prevent wrong-account commits (see 'ghs guard')
EOF

    # Only show these commands when sourced
    if ! is_standalone; then
        cat << 'EOF'
  auto-switch         Automatic profile switching by directory
  fish-setup          Set up gh-switcher for Fish shell
EOF
    fi

    cat << 'EOF'
  help                Show this help message

OPTIONS:
  --ssh-key <path>      Specify SSH key for add command
  --host <domain>       Specify GitHub host (default: github.com)

EXAMPLES:
  ghs add current                             Add currently authenticated GitHub user
  ghs add alice                               Add specific user  
  ghs add bob --ssh-key ~/.ssh/id_rsa_work    Add user with SSH key
  ghs add work --host github.company.com      Add enterprise user
  ghs edit alice --host github.enterprise.com
  ghs switch 1
  ghs assign alice
  ghs status
EOF

    # Only show auto-switch examples when sourced
    if ! is_standalone; then
        cat << 'EOF'

AUTO-SWITCHING:
  ghs auto-switch enable     Turn on automatic profile switching
  ghs auto-switch test       Preview what would happen in current directory
  ghs auto-switch status     Check configuration and assigned directories
EOF
    fi

    # Add note about installation mode
    if is_standalone; then
        cat << 'EOF'

NOTE: Running in standalone mode (Homebrew installation).
      Some features require shell integration. For full features, see:
      https://github.com/seconds-0/gh-switcher#manual-installation
EOF
    fi
}
```

### 4. Blocked Command Implementations

#### Auto-switch Command
```bash
cmd_auto_switch() {
    if is_standalone; then
        local install_method=$(get_installation_method)
        local uninstall_cmd=""
        
        case "$install_method" in
            Homebrew)
                uninstall_cmd="brew uninstall gh-switcher"
                ;;
            npm-global)
                uninstall_cmd="npm uninstall -g gh-switcher"
                ;;
            *)
                uninstall_cmd="Remove current installation"
                ;;
        esac
        
        cat << EOF
❌ Auto-switch requires shell integration

You're running gh-switcher via ${install_method} installation.
This feature needs to hook into your shell's 'cd' command.

To enable auto-switching:
1. Uninstall current version:
   ${uninstall_cmd}
   
2. Install with shell integration:
   https://github.com/seconds-0/gh-switcher#manual-installation

Alternative: Use 'ghs assign <user>' to manually set directories:
  ghs assign alice     # Set current directory to use 'alice' account
  ghs assign --list    # Show all directory assignments
EOF
        return 1
    fi
    
    # ... existing auto-switch implementation continues ...
}
```

#### Fish Setup Command
```bash
cmd_fish_setup() {
    if is_standalone; then
        cat << 'EOF'
❌ Fish setup requires shell integration

This command sets up Fish shell integration, which isn't
applicable for standalone installations.

To use gh-switcher with Fish:
1. Uninstall via Homebrew: brew uninstall gh-switcher
2. Follow Fish installation: https://github.com/seconds-0/gh-switcher#fish-shell
EOF
        return 1
    fi
    
    # ... existing fish-setup implementation continues ...
}
```

### 5. Status Command Enhancement

Add installation type info to `cmd_status()`:

```bash
cmd_status() {
    # ... existing status code ...
    
    # Add installation mode info at the end
    echo ""
    if is_standalone; then
        local install_method=$(get_installation_method)
        echo "📦 Installation: ${install_method} (standalone mode)"
        echo "   Limited features: auto-switch, fish-setup"
        echo "   For full features: https://github.com/seconds-0/gh-switcher#manual-installation"
    else
        echo "📦 Installation: Shell integration (full features)"
    fi
}
```

### 6. Doctor Command Enhancement

Update `cmd_doctor()` to show more detailed installation info:

```bash
cmd_doctor() {
    # ... existing doctor output ...
    
    echo ""
    echo "📦 Installation Details:"
    if is_standalone; then
        local install_method=$(get_installation_method)
        echo "   Type: ${install_method}"
        echo "   Mode: Standalone executable"
        echo "   Path: $0"
        echo "   Limited commands:"
        echo "     - auto-switch (requires shell integration)"
        echo "     - fish-setup (requires shell integration)"
        echo ""
        echo "   To enable all features:"
        echo "     https://github.com/seconds-0/gh-switcher#manual-installation"
    else
        echo "   Type: Manual/Shell sourced"
        echo "   Mode: Full shell integration"
        echo "   All features available"
    fi
}
```

### 7. Version Command (New)

Add a version command to show installation details:

```bash
cmd_version() {
    local version="${GHS_VERSION:-0.1.0}"
    echo "gh-switcher v${version}"
    
    if is_standalone; then
        local install_method=$(get_installation_method)
        echo "Installation: ${install_method} (standalone)"
    else
        echo "Installation: Shell integrated"
    fi
    
    echo "GitHub: https://github.com/seconds-0/gh-switcher"
}
```

### 8. Main Dispatcher Update

Update the main `ghs()` function to handle version command and first-run experience:

```bash
ghs() {
    local cmd="${1:-status}"
    shift 2>/dev/null || true
    
    # Strip out anything that isn't alphanumeric, dash, or underscore
    cmd="${cmd//[^a-zA-Z0-9_-]/}"
    
    # Initialize configuration
    init_config
    
    # First-run detection for standalone installations
    if [[ ! -f ~/.gh-switcher-welcomed ]] && is_standalone; then
        echo "ℹ️  Running gh-switcher in standalone mode (some features limited)"
        echo "   Run 'ghs help' to see available commands"
        touch ~/.gh-switcher-welcomed
    fi
    
    case "$cmd" in
        # ... existing cases ...
        (version|--version|-v) cmd_version ;;
        (*) echo "❌ Unknown command: $cmd"
            echo "Try 'ghs help' for usage information"
            return 1 ;;
    esac
}
```

## Documentation Updates Required

### 1. README.md Updates

Add a new "Installation Methods" section with feature comparison:

```markdown
## Installation Methods

### Quick Comparison

| Feature | Homebrew | npm global | Manual (sourced) |
|---------|----------|------------|------------------|
| Basic commands (add, switch, etc.) | ✅ | ✅ | ✅ |
| Guard hooks | ✅ | ✅ | ✅ |
| Auto-switch on `cd` | ❌ | ❌ | ✅ |
| Fish shell setup | ❌ | ❌ | ✅ |
| Shell aliases | ❌ | ❌ | ✅ |

### Via Homebrew (macOS/Linux)
```bash
brew tap seconds-0/tap
brew install gh-switcher
```

**Note**: Homebrew installation runs as a standalone executable with some limitations:
- ❌ `auto-switch` command not available (requires shell integration)
- ❌ `fish-setup` command not available (requires shell integration)
- ✅ All other commands work normally

For full feature support, use manual installation below.

### Via npm (all platforms)
```bash
npm install -g gh-switcher
```

**Note**: npm global installation has the same limitations as Homebrew.

### Manual Installation (full features)
For complete functionality including auto-switching:
```bash
# Download and source in your shell profile
curl -fsSL https://raw.githubusercontent.com/seconds-0/gh-switcher/main/install.sh | bash
```
```

### 2. CHANGELOG.md Entry

```markdown
## [Unreleased]

### Added
- Automatic detection of installation method (Homebrew/npm/manual)
- Graceful handling of unavailable features in standalone mode
- `version` command to show installation details
- First-run message for standalone installations

### Changed
- Help text now shows only available commands based on installation method
- Error messages provide specific uninstall instructions
- Doctor and status commands show installation type

### Documentation
- Added installation method comparison table
- Clear documentation of feature limitations
- Migration guide for switching installation methods
```

### 3. Migration Guide (new file: MIGRATION.md)

```markdown
# Migrating Between Installation Methods

## From Homebrew/npm to Manual Installation

If you need features like auto-switching, follow these steps:

1. **Save your current configuration**:
   ```bash
   ghs users > ~/gh-switcher-backup.txt
   ghs assign --list >> ~/gh-switcher-backup.txt
   ```

2. **Uninstall current version**:
   ```bash
   # For Homebrew
   brew uninstall gh-switcher
   
   # For npm
   npm uninstall -g gh-switcher
   ```

3. **Install manually**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/seconds-0/gh-switcher/main/install.sh | bash
   ```

4. **Verify installation**:
   ```bash
   ghs version  # Should show "Shell integrated"
   ```

Your users and assignments are preserved in `~/.gh-*` files.
```

### 4. Homebrew Formula Updates

Update `homebrew-tap/Formula/gh-switcher.rb`:

```ruby
class GhSwitcher < Formula
  desc "Lightning-fast GitHub account switcher for developers with multiple identities"
  homepage "https://github.com/seconds-0/gh-switcher"
  url "https://github.com/seconds-0/gh-switcher/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "01658b926ff101a4116bed8138f236567a0ef75c0cf1534a97d58469138cd5c8"
  license "MIT"

  depends_on "gh"
  depends_on "git"

  def install
    bin.install "gh-switcher.sh" => "ghs"
    
    # Install version file for detection
    (share/"gh-switcher").mkpath
    (share/"gh-switcher/VERSION").write version
  end

  def caveats
    <<~EOS
      gh-switcher is installed as a standalone executable.
      
      Some features require shell integration:
      - auto-switch (automatic profile switching when changing directories)
      - fish-setup (Fish shell configuration)
      
      All other features work normally. For full functionality, install manually:
        https://github.com/seconds-0/gh-switcher#manual-installation
    EOS
  end

  test do
    assert_match "GitHub Project Switcher", shell_output("#{bin}/ghs help")
    assert_match "standalone", shell_output("#{bin}/ghs version")
  end
end
```

### 5. UPDATING.md for homebrew-tap

Create `homebrew-tap/UPDATING.md`:

```markdown
# Updating the gh-switcher Formula

## When releasing a new version:

1. **Get the new SHA256**:
   ```bash
   curl -sL https://github.com/seconds-0/gh-switcher/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```

2. **Update Formula**:
   - Change `url` to new version tag
   - Update `sha256` with new hash
   - Update version number if needed

3. **Test locally**:
   ```bash
   brew uninstall gh-switcher
   brew install --build-from-source Formula/gh-switcher.rb
   ghs version  # Verify correct version
   ```

4. **Commit and push**:
   ```bash
   git add Formula/gh-switcher.rb
   git commit -m "gh-switcher: update to vX.Y.Z"
   git push
   ```

Users will receive updates via `brew upgrade`.
```

## Testing Plan

### 1. Unit Tests
Create new test file `test/standalone-detection.bats`:

```bash
#!/usr/bin/env bats

load test_helper

@test "detection: sourced script detected correctly" {
    run bash -c "source $GHS_PATH && is_standalone"
    assert_failure
}

@test "detection: executed script detected correctly" {
    run bash -c "$GHS_PATH help"
    assert_success
    assert_output --partial "NOTE: Running in standalone mode"
}

@test "detection: symlink detected as standalone" {
    ln -s "$GHS_PATH" "$BATS_TEST_TMPDIR/ghs-link"
    run "$BATS_TEST_TMPDIR/ghs-link" help
    assert_success
    assert_output --partial "standalone mode"
}

@test "help: auto-switch hidden in standalone mode" {
    run bash -c "$GHS_PATH help"
    assert_success
    refute_output --partial "auto-switch"
}

@test "help: auto-switch shown when sourced" {
    run bash -c "source $GHS_PATH && ghs help"
    assert_success
    assert_output --partial "auto-switch"
}

@test "version: shows installation method" {
    run bash -c "$GHS_PATH version"
    assert_success
    assert_output --partial "Installation:"
}

@test "auto-switch: helpful error in standalone mode" {
    run bash -c "$GHS_PATH auto-switch enable"
    assert_failure
    assert_output --partial "Auto-switch requires shell integration"
}

@test "doctor: shows installation details" {
    run bash -c "$GHS_PATH doctor"
    assert_success
    assert_output --partial "Installation Details:"
}
```

### 2. Performance Tests

```bash
# Ensure detection doesn't slow down commands
time ghs status  # Should be < 100ms
time ghs help    # Should be < 100ms
```

### 3. Manual Testing Checklist
- [ ] Source script and verify all commands available
- [ ] Run as executable and verify commands hidden
- [ ] Install via Homebrew and verify detection works
- [ ] Install via npm global and verify detection works  
- [ ] Test each blocked command shows helpful message
- [ ] Verify all other commands work normally in both modes
- [ ] Test first-run message appears only once
- [ ] Test version command shows correct installation type
- [ ] Test migration between installation methods preserves config

### 4. Edge Cases to Test
- Different shells (bash, zsh, fish)
- Symlinked installations
- Custom Homebrew paths
- Linux Homebrew paths
- Running through shell scripts
- Aliases to ghs command
- Running with DEBUG=true shows detection reasoning

## Migration Path

1. Create feature branch: `feature/homebrew-standalone-detection`
2. Implement detection function
3. Update help command
4. Update blocked commands
5. Update status command
6. Add tests
7. Test locally with both installation methods
8. Update Homebrew formula to test branch
9. Get user feedback
10. Merge to develop
11. Eventually merge to main for release

## Alternative Approaches Considered

### 1. Init Command Pattern
Like `rbenv`, `pyenv`, `direnv`:
```bash
eval "$(ghs init zsh)"
```
- Pros: Enables full features even with Homebrew
- Cons: Extra step for users, more complex

### 2. Wrapper Script
Install a separate sourcing script:
```bash
brew install gh-switcher
source $(brew --prefix)/share/gh-switcher/init.sh
```
- Pros: Full features with Homebrew
- Cons: More complex installation

### 3. Do Nothing
Leave all commands visible:
- Pros: Simple
- Cons: User confusion when features don't work

## Decision
Go with the detection and hiding approach because:
1. Simplest for users
2. Clear about limitations
3. Provides upgrade path
4. No breaking changes

## Future Enhancements
1. Consider adding `ghs init` command later if users request it
2. Add telemetry to see how many users hit the blocked commands
3. Create a migration guide for Homebrew → manual installation

## Implementation Checklist

### Code Changes
- [ ] Add `is_standalone()` function
- [ ] Add `get_installation_method()` function  
- [ ] Update `cmd_help()` to conditionally show commands
- [ ] Update `cmd_auto_switch()` with helpful error message
- [ ] Update `cmd_fish_setup()` with helpful error message
- [ ] Update `cmd_status()` to show installation type
- [ ] Update `cmd_doctor()` with installation details
- [ ] Add new `cmd_version()` command
- [ ] Update main `ghs()` dispatcher for version and first-run
- [ ] Add `GHS_VERSION` variable at top of script

### Documentation Changes
- [ ] Update README.md with installation comparison table
- [ ] Create MIGRATION.md guide
- [ ] Update CHANGELOG.md
- [ ] Create homebrew-tap/UPDATING.md
- [ ] Update Homebrew formula with caveats

### Testing
- [ ] Create test/standalone-detection.bats
- [ ] Test all edge cases manually
- [ ] Performance testing
- [ ] CI integration for Homebrew testing

## Success Criteria
- [ ] Users understand why features are unavailable
- [ ] No confusion about broken commands  
- [ ] Clear path to get full features
- [ ] No regression for existing users
- [ ] Clean implementation under 50 lines per function
- [ ] Performance impact < 10ms
- [ ] All tests passing
- [ ] Documentation is clear and comprehensive

## Rollback Plan
If issues are discovered:
1. Revert the feature branch
2. Update Homebrew formula to previous version
3. Document lessons learned
4. Consider alternative approaches (init command pattern)

## Future Enhancements
1. **Init Command Pattern** (Phase 2):
   ```bash
   eval "$(ghs init zsh)"
   ```
   This would enable full features even with Homebrew/npm

2. **Telemetry** (Optional):
   Track how often users hit the blocked commands to prioritize future work

3. **Automatic Migration**:
   Offer to help users migrate to manual installation when they try blocked commands

## Summary
This plan ensures that users have a clear understanding of what features are available based on their installation method, with helpful guidance on how to access full functionality when needed. The implementation is backwards-compatible and provides a smooth user experience regardless of installation method.