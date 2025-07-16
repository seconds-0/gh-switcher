# E2E Tests Plan - VS Code Terminal Environment

> 📝 **Plan Status**: Critically reviewed and updated based on VS Code documentation
> 
> Last review: 2025-07-15 - See E2E-TESTS-VSCODE-CRITICAL-REVIEW.md for details

## Overview
VS Code terminals have unique characteristics that can cause issues with shell scripts. This plan covers comprehensive testing of gh-switcher in VS Code's integrated terminal across different configurations.

## VS Code Terminal Characteristics

### 1. Special Environment Variables
VS Code sets these environment variables that can affect scripts:

#### Confirmed Variables (from documentation):
- `TERM_PROGRAM=vscode` - Identifies VS Code terminal
- `VSCODE_GIT_IPC_HANDLE` - Git integration IPC channel
- `VSCODE_GIT_ASKPASS_NODE` - Node.js path for Git auth (VS Code executable)
- `VSCODE_GIT_ASKPASS_MAIN` - Askpass script location
- `VSCODE_GIT_ASKPASS_EXTRA_ARGS` - Additional Git auth args
- `GIT_ASKPASS` - Points to askpass shell script
- `VSCODE_INJECTION=1` - Set when VS Code injects environment

#### Unconfirmed/Undocumented Variables:
- `VSCODE_SHELL_ENV_REPORTING` - ⚠️ Not in official docs (but caused our bug!)
- `VSCODE_CWD` - May be version/platform specific

#### Extension-Contributed Variables:
- Python extension variables
- Node.js extension variables
- User-configured via `terminal.integrated.env.*`

### 2. Shell Integration Features
VS Code automatically injects shell integration that:
- Uses OSC 633 escape sequences for communication
- Tracks command execution and exit codes
- Shows command decorations (success/failure indicators)
- Detects current working directory
- Enables command navigation
- Can be disabled via `terminal.integrated.shellIntegration.enabled`
- Supports manual installation for unsupported shells
- Works automatically with: bash, zsh, fish, pwsh, Git Bash

### 3. Remote Contexts
VS Code can run in multiple contexts:
- Local integrated terminal
- Remote SSH sessions
- Dev Containers
- GitHub Codespaces
- WSL (Windows Subsystem for Linux)

## Test Categories

### 1. Basic VS Code Terminal Tests

#### Test 1.1: VS Code Environment Preservation
```bash
@test "e2e: vscode: preserves VS Code environment variables" {
    # Simulate VS Code environment
    export TERM_PROGRAM=vscode
    export VSCODE_GIT_IPC_HANDLE="/tmp/vscode-git-ipc.sock"
    export VSCODE_GIT_ASKPASS_NODE="/usr/local/bin/node"
    export VSCODE_INJECTION=1
    export VSCODE_SHELL_ENV_REPORTING=1
    
    # Source gh-switcher
    # Verify all VS Code variables still exist and work
    # Verify no "unbound variable" errors
}
```

#### Test 1.2: Shell Integration Compatibility
```bash
@test "e2e: vscode: works with VS Code shell integration" {
    # Set up VS Code's prompt modifications
    # Test that gh-switcher doesn't break:
    # - Command tracking
    # - Exit code reporting
    # - Directory markers
    # - Prompt rendering
}
```

#### Test 1.3: Git Integration Compatibility
```bash
@test "e2e: vscode: compatible with VS Code Git integration" {
    # Test that gh-switcher works with:
    # - VS Code's Git authentication
    # - Git operations through VS Code
    # - Credential helpers
}
```

### 2. Shell-Specific VS Code Tests

#### Test 2.1: VS Code + Bash
```bash
@test "e2e: vscode bash: full integration test" {
    export TERM_PROGRAM=vscode
    # Test bash-specific VS Code features
    # Test PROMPT_COMMAND modifications
}
```

#### Test 2.2: VS Code + Zsh
```bash
@test "e2e: vscode zsh: full integration test" {
    export TERM_PROGRAM=vscode
    # Test zsh-specific VS Code features
    # Test precmd/preexec hooks
}
```

#### Test 2.3: VS Code + PowerShell
```bash
@test "e2e: vscode pwsh: basic compatibility check" {
    # Test if gh-switcher at least doesn't break PowerShell
    # Note: Full support would need gh-switcher.ps1
}
```

### 3. Remote Development Tests

#### Test 3.1: VS Code Remote SSH
```bash
@test "e2e: vscode remote ssh: works in remote sessions" {
    # Simulate remote SSH environment
    export SSH_CLIENT="192.168.1.100 12345 22"
    export TERM_PROGRAM=vscode
    # Test with limited remote environment
}
```

#### Test 3.2: VS Code Dev Containers
```bash
@test "e2e: vscode devcontainer: works in containers" {
    # Simulate container environment
    export REMOTE_CONTAINERS=true
    export TERM_PROGRAM=vscode
    # Test with container-specific paths
}
```

#### Test 3.3: GitHub Codespaces
```bash
@test "e2e: vscode codespaces: works in cloud environments" {
    # Simulate Codespaces environment
    export CODESPACES=true
    export TERM_PROGRAM=vscode
    # Test with Codespaces-specific setup
}
```

### 4. Edge Cases and Bug Prevention

#### Test 4.1: Unset Variable Errors (Critical - Caught Production Bug)
```bash
@test "e2e: vscode: no unset variable errors with strict mode" {
    # This test specifically catches the VSCODE_SHELL_ENV_REPORTING bug
    set -euo pipefail
    export TERM_PROGRAM=vscode
    
    # Test with undocumented variables that may or may not exist
    # VSCODE_SHELL_ENV_REPORTING caused our production bug!
    unset VSCODE_SHELL_ENV_REPORTING 2>/dev/null || true
    
    # Source gh-switcher and ensure no errors
    source "$script_path"
    
    # Run basic command to ensure functionality
    ghs status
}
```

#### Test 4.1b: Document All VS Code Variables
```bash
@test "e2e: vscode: discover and document all environment variables" {
    # Compare environment in VS Code vs regular terminal
    # Document any undocumented variables found
    # Update our defensive checks accordingly
}
```

#### Test 4.2: PATH Preservation in VS Code
```bash
@test "e2e: vscode: preserves PATH with VS Code modifications" {
    # VS Code may modify PATH for extensions
    # Ensure gh-switcher doesn't break this
}
```

#### Test 4.3: Terminal Restart Resilience
```bash
@test "e2e: vscode: survives terminal restart/reload" {
    # Test multiple sourcing after terminal restart
    # VS Code may reload shell config
}
```

## Implementation Strategy

### 1. Test Helpers
```bash
# helpers/vscode_helper.bash
setup_vscode_env() {
    export TERM_PROGRAM=vscode
    export VSCODE_GIT_IPC_HANDLE="/tmp/vscode-git-ipc-$$.sock"
    export VSCODE_GIT_ASKPASS_NODE="$(which node 2>/dev/null || echo /usr/bin/node)"
    export VSCODE_GIT_ASKPASS_MAIN="/tmp/vscode/git-askpass-main.js"
    export VSCODE_INJECTION=1
    export VSCODE_SHELL_ENV_REPORTING=1
    export VSCODE_CWD="$PWD"
}

simulate_vscode_shell_integration() {
    # Add VS Code's prompt modifications
    if [[ -n "${BASH_VERSION:-}" ]]; then
        PROMPT_COMMAND="__vscode_prompt_cmd; $PROMPT_COMMAND"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        precmd_functions+=(__vscode_precmd)
    fi
}
```

### 2. Mock VS Code Commands
```bash
create_mock_code() {
    cat > "$HOME/bin/code" << 'EOF'
#!/bin/bash
# Mock VS Code CLI
case "$1" in
    --version) echo "1.85.0" ;;
    --status) echo "Running" ;;
    *) echo "Mock VS Code: $@" ;;
esac
EOF
    chmod +x "$HOME/bin/code"
}
```

## Priority Order

1. **CRITICAL**: Test 4.1 - Unset variable errors (this exact test would have prevented our production bug)
2. **High Priority**: Document all VS Code environment variables
3. **High Priority**: Shell integration compatibility (both enabled and disabled)
4. **High Priority**: Git environment variable handling
5. **Medium Priority**: Remote development scenarios
6. **Low Priority**: Advanced features and edge cases

## Success Criteria

- All tests pass in simulated VS Code environment
- No unset variable errors with `set -euo pipefail`
- Shell integration features remain functional
- Git operations work correctly
- Performance remains under 300ms startup time

## Notes

- VS Code version differences may affect behavior
- Some features may require actual VS Code instance (manual testing)
- Consider testing with popular VS Code extensions that modify terminal
- **IMPORTANT**: VSCODE_SHELL_ENV_REPORTING is undocumented but real - it caused our production bug
- Shell integration can be disabled by users, test both scenarios
- Git-related variables are critical for VS Code's Git functionality