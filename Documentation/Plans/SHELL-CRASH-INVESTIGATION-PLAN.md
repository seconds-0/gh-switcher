# Shell Crash Investigation Plan

## Problem Statement
- `ghs remove 1` crashes terminal in zsh/vscode
- `npm run reset` (shell-reset.sh) also terminates zsh with exit code 1
- This suggests a systemic issue with our shell scripts in zsh

## Investigation Steps

### Phase 1: Immediate Diagnostics (10 minutes)

1. **Check shell-reset.sh script**
   ```bash
   cat scripts/shell-reset.sh
   # Look for any problematic commands
   ```

2. **Check npm script definition**
   ```bash
   npx json -f package.json scripts.shell-reset
   ```

3. **Test direct execution**
   ```bash
   # Try running directly instead of through npm
   bash scripts/shell-reset.sh
   # vs
   ./scripts/shell-reset.sh
   ```

4. **Check for error patterns**
   ```bash
   # Look for common zsh-incompatible patterns
   grep -E "set -e|set -u|exit|kill|exec" scripts/shell-reset.sh
   ```

### Phase 2: Isolate the Problem (15 minutes)

1. **Test in different shells**
   ```bash
   # Test in bash
   bash -c './scripts/shell-reset.sh'
   
   # Test in sh
   sh -c './scripts/shell-reset.sh'
   
   # Test with explicit zsh
   zsh -c './scripts/shell-reset.sh'
   ```

2. **Debug mode execution**
   ```bash
   # Run with xtrace to see exactly where it fails
   zsh -x scripts/shell-reset.sh 2>&1 | tail -20
   
   # Or with verbose mode
   zsh -v scripts/shell-reset.sh 2>&1 | tail -20
   ```

3. **Check for shell options conflicts**
   ```bash
   # Current shell options
   set -o
   
   # Check if script changes critical options
   grep -E "setopt|unsetopt|set [+-]" scripts/shell-reset.sh
   ```

### Phase 3: Investigate ghs remove Command (20 minutes)

1. **Find remove command implementation**
   ```bash
   grep -n "cmd_remove" gh-switcher.sh
   ```

2. **Test remove with debug output**
   ```bash
   # Add debug output to see where it crashes
   GHS_DEBUG=1 ghs remove 1
   ```

3. **Check for array/variable issues**
   ```bash
   # Common zsh issues with arrays and word splitting
   grep -A10 -B10 "cmd_remove" gh-switcher.sh | grep -E '\$@|\$\*|array|shift'
   ```

4. **Test with different inputs**
   ```bash
   # Test with username instead of number
   ghs remove nonexistent
   
   # Test with no arguments
   ghs remove
   
   # Test with invalid number
   ghs remove 999
   ```

### Phase 4: Common Zsh Incompatibilities (15 minutes)

1. **Array indexing differences**
   - Bash: arrays start at 0
   - Zsh: arrays start at 1 (by default)
   
   Check for:
   ```bash
   grep -E "array\[|{\$.*\[" gh-switcher.sh
   ```

2. **Word splitting differences**
   ```bash
   # Check for unquoted variables that might split differently
   grep -E '\$[A-Za-z_]+[^"]|`[^`]+`[^"]' gh-switcher.sh
   ```

3. **Function return behavior**
   ```bash
   # Check for functions that might exit the shell
   grep -B5 "exit" gh-switcher.sh
   grep -B5 "return" scripts/shell-reset.sh
   ```

4. **POSIX compliance issues**
   ```bash
   # Check for bash-specific syntax
   shellcheck -s bash gh-switcher.sh | grep -i "not POSIX"
   ```

### Phase 5: Fix Strategies (10 minutes)

Based on findings, common fixes include:

1. **Explicit bash interpreter**
   ```bash
   #!/usr/bin/env bash
   # Instead of #!/bin/bash
   ```

2. **Array compatibility**
   ```bash
   # Use associative arrays carefully
   # Quote array expansions
   "${array[@]}"
   ```

3. **Exit vs Return**
   ```bash
   # In sourced functions, use return not exit
   # Check if we're being sourced
   [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit
   ```

4. **Defensive coding**
   ```bash
   # Set shell options explicitly
   set -euo pipefail 2>/dev/null || true
   
   # Handle zsh array indexing
   if [[ -n "${ZSH_VERSION:-}" ]]; then
       setopt KSH_ARRAYS 2>/dev/null || true
   fi
   ```

## Success Criteria

1. `ghs remove 1` works without crashing the terminal
2. `npm run shell-reset` completes successfully
3. All commands work in both bash and zsh
4. No terminal exits with error code 1

## Priority Order

1. First fix shell-reset.sh (simpler, isolated script)
2. Then fix ghs remove command
3. Add defensive coding to prevent future issues
4. Add tests for both scenarios