# Simple Homebrew Standalone Detection Plan

## Problem
When installed via Homebrew, `auto-switch` and `fish-setup` commands don't work because they need shell integration. Users get confusing errors.

## Solution
Hide these 2 commands and show helpful errors if users try them.

## Implementation (4 small changes)

### 1. Add Detection Function (10 lines)
After configuration section in `gh-switcher.sh`:

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
```

### 2. Update Help Command
In `cmd_help()`, conditionally show the 2 affected commands:

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
  users               List all accounts with SSH/HTTPS status
  show <user>         View account details and diagnose issues
  edit <user>         Update email, SSH key, or host settings
  test-ssh [<user>]   Verify SSH key works with GitHub
  status              Show current account and project state (default)
  doctor              Show diagnostics for troubleshooting
  guard               Prevent wrong-account commits (see 'ghs guard')
EOF

    # Only show these when sourced
    if ! is_standalone; then
        cat << 'EOF'
  auto-switch         Automatic profile switching by directory
  fish-setup          Set up gh-switcher for Fish shell
EOF
    fi

    cat << 'EOF'
  help                Show this help message
EOF
}
```

### 3. Block Unavailable Commands
Simple error messages for the 2 commands:

```bash
cmd_auto_switch() {
    if is_standalone; then
        echo "❌ Auto-switch requires shell integration"
        echo "   See: https://github.com/seconds-0/gh-switcher#manual-installation"
        return 1
    fi
    
    # ... existing implementation ...
}

cmd_fish_setup() {
    if is_standalone; then
        echo "❌ Fish setup requires shell integration"
        echo "   See: https://github.com/seconds-0/gh-switcher#manual-installation"
        return 1
    fi
    
    # ... existing implementation ...
}
```

### 4. Update Homebrew Formula
Add caveats to `homebrew-tap/Formula/gh-switcher.rb`:

```ruby
def caveats
  <<~EOS
    Some features require shell integration:
    - auto-switch (automatic profile switching)
    - fish-setup (Fish shell configuration)
    
    For these features, see manual installation:
    https://github.com/seconds-0/gh-switcher#manual-installation
  EOS
end
```

## Testing
1. Source the script: `source gh-switcher.sh && ghs help` - should show all commands
2. Run directly: `./gh-switcher.sh help` - should hide auto-switch and fish-setup
3. Try blocked command: `./gh-switcher.sh auto-switch` - should show error message

## That's It!
- 4 small code changes
- ~30 lines of code total
- No new commands or complex detection
- Users see only what works

No need for:
- Version commands
- Installation method detection  
- First-run messages
- Migration guides
- Complex testing
- Debug modes