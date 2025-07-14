# E2E Terminal Testing Implementation Steps

## Phase 1: MVP - Critical Shell Compatibility Tests
**Goal**: Catch shell-specific bugs like the zsh PATH issue

### Step 1: Create E2E test directory structure
```
tests/
  e2e/
    helpers/
      e2e_helper.bash     # Common E2E test utilities
    test_shell_sourcing.bats
    test_basic_flow.bats
```

### Step 2: Implement the 5 most critical tests
1. **zsh PATH preservation test** - Would have caught our bug
2. **Multiple sourcing test** - Readonly variable errors
3. **Basic command flow** - add/switch/remove cycle
4. **Shell startup performance** - Under 300ms
5. **Environment isolation** - No pollution between commands

### Step 3: E2E test helper functions
- `setup_clean_test_env()` - Fresh environment for each test
- `mock_gh_cli()` - Predictable gh behavior
- `assert_shell_command()` - Run command in real shell
- `cleanup_test_env()` - Clean up after tests

## Phase 2: Interactive Testing (Week 2)
**Goal**: Test user input scenarios

### Step 4: Add expect-based tests
- Interactive `ghs add` flow
- Password/token input handling
- Confirmation prompts

### Step 5: Error scenario testing
- Invalid inputs
- Missing dependencies
- Corrupted config files

## Phase 3: Integration Testing (Week 3)
**Goal**: Test git integration and complex workflows

### Step 6: Git workflow tests
- Guard hook installation
- Pre-commit validation
- Multi-user commit scenarios

### Step 7: Performance benchmarks
- Command execution times
- Startup overhead
- Large user list handling

## Implementation Priority

### Today (MVP):
1. Create `tests/e2e/` directory structure
2. Write `test_shell_sourcing.bats` with:
   - zsh PATH test
   - bash sourcing test
   - multiple source test
3. Create minimal `e2e_helper.bash`
4. Run and verify tests catch the zsh bug

### This Week:
- Complete Phase 1 (5 critical tests)
- Set up CI to run E2E tests
- Document E2E test patterns

### Next Week:
- Begin Phase 2 (interactive tests)
- Add expect-based test examples

## Success Criteria
- [x] E2E tests would have caught the zsh PATH bug
- [ ] Tests run in both bash and zsh
- [ ] Tests complete in <10 seconds
- [ ] Clear failure messages for debugging
- [ ] CI integration working

## Tools Required
- ✅ BATS - Already installed
- ✅ expect - Already installed  
- ✅ script - Already installed
- ✅ bash/zsh - Already available

## Next Actions
1. Create directory structure
2. Write first E2E test for zsh PATH issue
3. Verify it fails without our fix
4. Verify it passes with our fix