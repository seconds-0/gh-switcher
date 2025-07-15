# E2E Shell Testing - Simplified Summary

## Philosophy
**Test that gh-switcher doesn't break, not that other shells work perfectly.**

## Total Tests: 11 (not 100+)

### VS Code (3 tests)
1. Don't crash with unset variables ✅ (would have caught our bug)
2. Basic commands work
3. Git integration works

### PowerShell (2 tests)
1. Doesn't break PowerShell
2. Document wrapper function

### Fish (3 tests)
1. Wrapper function works
2. Switches persist across shells
3. Git config updates work

### Dash (3 tests)
1. Sources without syntax errors
2. Basic commands work
3. No bashisms break core functionality

## What We're NOT Testing
- Shell-specific features
- Performance in each shell
- Deep integration
- Remote/container scenarios
- Version-specific behavior
- Extension compatibility

## Implementation Priority
1. **VS Code tests** - Critical (catches real bugs)
2. **Dash tests** - High (ensures POSIX compliance)
3. **Fish tests** - Medium (common alternative shell)
4. **PowerShell tests** - Low (just document limitations)

## Maintenance Burden
- **Before**: 40+ complex tests requiring deep shell knowledge
- **After**: 11 simple tests that just verify basics work

## Success Metrics
- [ ] Would have caught the VS Code bug
- [ ] Takes <5 minutes to run all tests
- [ ] No false positives from shell updates
- [ ] Clear documentation for unsupported shells

## Next Steps
1. Implement these 11 tests
2. Delete the complex plans
3. Add shell compatibility notes to README
4. Ship it

Remember: Perfect is the enemy of good. These tests catch real issues without creating maintenance hell.