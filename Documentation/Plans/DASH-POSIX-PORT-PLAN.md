# Dash/POSIX Shell Port Plan

## Executive Summary
This document outlines what it would take to make gh-switcher fully POSIX-compliant and run natively in dash/sh.

## Current State
- gh-switcher requires bash due to several bashisms
- Users can work around this by invoking through bash
- Documented in `docs/POSIX_SHELL_USAGE.md`

## Is Dash Support Important?

### Arguments FOR:
1. **Docker/Container Usage**: Many containers use dash as /bin/sh for smaller size
2. **CI/CD Environments**: Some minimal CI environments only have sh
3. **Embedded Systems**: Resource-constrained systems often use busybox sh
4. **Best Practice**: POSIX compliance improves portability
5. **Performance**: Dash is faster than bash for scripts

### Arguments AGAINST:
1. **Bash is Ubiquitous**: Available on virtually all development machines
2. **Workarounds Exist**: Can invoke via `bash -c` easily
3. **Maintenance Burden**: POSIX restrictions make code harder to maintain
4. **Feature Limitations**: Some features are much harder without bashisms
5. **User Base**: Most gh-switcher users are on macOS/Linux with bash

## Required Changes

### 1. Conditional Syntax
```bash
# Current (bash)
[[ "$var" == "value" ]]
[[ -z "$var" ]]
[[ ! "$var" =~ ^[pattern]$ ]]

# POSIX
[ "$var" = "value" ]
[ -z "$var" ]
# Regex would need grep or case statements
```

### 2. String Operations
```bash
# Current (bash)
${#username}  # Length
${var:-default}  # Works in POSIX

# POSIX
expr length "$username"
# or
echo "$username" | wc -c
```

### 3. Regular Expressions
```bash
# Current (bash)
[[ "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]

# POSIX (using grep)
echo "$username" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$'

# Or using case (more portable)
case "$username" in
    [!a-zA-Z0-9]*|*[!a-zA-Z0-9]) return 1 ;;
    *--*) return 1 ;;
    *) return 0 ;;
esac
```

### 4. Arrays (Critical Issue)
Some functions use arrays for gathering options:
```bash
# Current (bash arrays)
local opts=()
opts+=("--name" "$name")

# POSIX alternative (string concatenation)
local opts=""
opts="$opts --name '$name'"
# But this has quoting issues
```

### 5. Process Substitution
```bash
# Current (if used)
diff <(cmd1) <(cmd2)

# POSIX
cmd1 > tmp1
cmd2 > tmp2
diff tmp1 tmp2
rm tmp1 tmp2
```

## Effort Estimate

### Phase 1: Analysis (1 week)
- Audit all bashisms in gh-switcher.sh
- Identify which features would be hardest to port
- Determine if any features would be impossible in POSIX

### Phase 2: Refactoring (2-3 weeks)
- Replace `[[` with `[`
- Convert regex matches to grep/case
- Replace string length operations
- Rewrite array-using functions
- Extensive testing after each change

### Phase 3: Testing (1 week)
- Test in dash, ash, busybox sh
- Test in minimal Docker containers
- Ensure no regressions in bash/zsh

Total: **4-5 weeks** of focused effort

## Recommendation

**DON'T PORT TO DASH** - Here's why:

1. **Cost/Benefit**: 4-5 weeks of work for marginal benefit
2. **Workarounds Work**: The bash invocation method is simple and reliable
3. **Maintenance Burden**: POSIX code is harder to read and maintain
4. **User Impact**: Very few users actually need pure POSIX support
5. **Better Alternative**: Document the limitation clearly (✓ already done)

## Alternative Approach

Instead of a full port, consider:

1. **Minimal POSIX Wrapper** (`ghs.sh`):
```sh
#!/bin/sh
# POSIX wrapper for gh-switcher
if [ -z "$BASH_VERSION" ]; then
    exec bash -c ". /path/to/gh-switcher.sh && ghs \"\$@\"" -- "$@"
else
    . /path/to/gh-switcher.sh
    ghs "$@"
fi
```

2. **Container-Specific Documentation**:
- Add Dockerfile examples
- Show how to ensure bash is available
- Provide pre-built images with gh-switcher

3. **Long-term**: If demand grows significantly, revisit this decision

## Conclusion

While POSIX compliance would be nice, the effort required (4-5 weeks) far exceeds the benefit. The current approach of requiring bash and providing clear documentation and workarounds is the pragmatic choice.

Users who need gh-switcher in dash environments can:
1. Install bash (usually trivial)
2. Use the documented wrapper approach
3. Contribute a POSIX port if they have strong need

This plan can be revisited if user demand justifies the investment.