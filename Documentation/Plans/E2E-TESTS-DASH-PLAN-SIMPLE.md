# E2E Tests Plan - Dash Shell (Simplified)

## Reality Check
Dash is POSIX sh. If we have bashisms, they'll break here. This is actually valuable to test.

## The Tests (Just 3)

### Test 1: Source Without Syntax Errors
```bash
@test "e2e: dash: can source without syntax errors" {
    command -v dash >/dev/null 2>&1 || skip "Dash not installed"
    
    # This will fail if we have bashisms
    dash -c ". $script_path; echo 'Sourced successfully'"
}
```

### Test 2: Basic Commands Work
```bash
@test "e2e: dash: basic commands work in POSIX sh" {
    command -v dash >/dev/null 2>&1 || skip "Dash not installed"
    
    # Run core commands
    dash -c "
        . $script_path
        ghs add dashuser
        ghs switch dashuser
        ghs status | grep -q dashuser
        ghs remove dashuser
    "
}
```

### Test 3: No Bash-Specific Features Break
```bash
@test "e2e: dash: no bashisms in critical path" {
    command -v dash >/dev/null 2>&1 || skip "Dash not installed"
    
    # Strict POSIX mode
    dash -c "
        set -e
        . $script_path
        
        # These should work without arrays, [[, etc.
        ghs users
        ghs status
    "
}
```

## What We're NOT Testing
- Every POSIX edge case
- Performance comparisons
- Init system compatibility
- Docker entrypoint scenarios
- Cron job usage

## Known Limitations
If gh-switcher uses bash-specific features:
- Arrays: `arr=(a b c)`
- `[[` conditions
- `source` command (use `.`)
- Process substitution `<()`
- Brace expansion `{1..10}`

Document these in README if we can't fix them.

## Why This Matters
- Ubuntu/Debian use dash as `/bin/sh`
- Good POSIX compliance = better portability
- Catches accidental bashisms

That's it. Three tests to ensure basic POSIX compatibility.