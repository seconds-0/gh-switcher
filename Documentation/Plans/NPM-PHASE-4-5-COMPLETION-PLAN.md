# NPM Package Phase 4-5 Completion Plan

## Overview
This plan addresses the gaps identified in our Phase 4 and 5 execution to ensure proper npm package testing and preparation.

## Phase 4 Gaps to Address

### 4.1 Global Installation Testing (CRITICAL)
**Priority**: HIGH  
**Time**: 20 minutes

**Steps**:
1. Create fresh test package
   ```bash
   npm pack
   # Verify package created
   ls -la gh-switcher-0.1.0.tgz
   ```

2. Test global installation
   ```bash
   # Check current global packages
   npm list -g --depth=0
   
   # Install globally
   npm install -g ./gh-switcher-0.1.0.tgz
   
   # Verify installation
   npm list -g gh-switcher
   ```

3. Verify command availability
   ```bash
   # Check command exists in PATH
   which ghs
   
   # Check it's a proper symlink
   ls -la $(which ghs)
   
   # Test basic execution
   ghs --version || ghs help
   ghs status
   ghs users
   ```

4. Test from different directories
   ```bash
   # Test from home directory
   cd ~ && ghs status
   
   # Test from temp directory (if allowed)
   cd /tmp && ghs help 2>/dev/null || echo "Temp dir test skipped"
   
   # Return to project
   cd -
   ```

5. Clean up global installation
   ```bash
   # Uninstall
   npm uninstall -g gh-switcher
   
   # Verify removal
   which ghs 2>/dev/null && echo "❌ Not fully removed" || echo "✅ Removed"
   ```

### 4.2 Edge Case Testing
**Priority**: MEDIUM  
**Time**: 15 minutes

**Steps**:
1. Test upgrade scenario
   ```bash
   # Install version 0.1.0
   npm install -g ./gh-switcher-0.1.0.tgz
   
   # Force reinstall (simulates upgrade)
   npm install -g ./gh-switcher-0.1.0.tgz --force
   
   # Verify still works
   ghs status
   
   # Clean up
   npm uninstall -g gh-switcher
   ```

2. Test with existing ghs function
   ```bash
   # Check if ghs already exists (from shell sourcing)
   type ghs
   
   # Install npm version
   npm install -g ./gh-switcher-0.1.0.tgz
   
   # Check which takes precedence
   which ghs
   type ghs
   
   # Clean up
   npm uninstall -g gh-switcher
   ```

### 4.3 Package Content Validation
**Priority**: HIGH  
**Time**: 10 minutes

**Steps**:
1. Extract and verify package contents
   ```bash
   # Create temp extraction directory
   mkdir -p test-extract
   cd test-extract
   
   # Extract package
   tar -xzf ../gh-switcher-0.1.0.tgz
   
   # Verify structure
   find package -type f -name "*" | sort
   
   # Check file permissions
   ls -la package/gh-switcher.sh
   # Should be executable (755 or similar)
   
   # Verify shebang line
   head -1 package/gh-switcher.sh
   # Should be: #!/usr/bin/env bash
   
   # Check file sizes
   du -h package/*
   
   # Clean up
   cd .. && rm -rf test-extract
   ```

### 4.4 Test Count Investigation
**Priority**: MEDIUM  
**Time**: 10 minutes

**Steps**:
1. Identify the missing test
   ```bash
   # Count expected tests
   grep -r "^@test" tests/ | wc -l
   
   # Run tests with verbose output
   npm test -- --verbose 2>&1 | tee test-output.log
   
   # Check for skipped tests
   grep -i "skip" test-output.log
   
   # Look for test execution issues
   grep -E "not ok|error|fail" test-output.log
   
   # Clean up
   rm -f test-output.log
   ```

## Phase 5 Gaps to Address

### 5.1 Complete Pre-publish Validation
**Priority**: HIGH  
**Time**: 10 minutes

**Steps**:
1. Run individual checks (since full script fails on test count)
   ```bash
   # Lint
   npm run lint
   echo "Lint: $?"
   
   # Build
   npm run build  
   echo "Build: $?"
   
   # Package validation
   npm pack --dry-run
   echo "Pack: $?"
   
   # Git status
   git status --porcelain
   ```

2. Verify all metadata
   ```bash
   # No placeholders
   grep -E "REPLACE_WITH|Your Name|your\.email" package.json && echo "❌ Found placeholders" || echo "✅ No placeholders"
   
   # Required fields present
   for field in name version description bin files author license repository bugs homepage; do
     npx json -f package.json $field >/dev/null && echo "✅ $field present" || echo "❌ $field missing"
   done
   
   # Verify bin executable
   [[ -x gh-switcher.sh ]] && echo "✅ Script executable" || echo "❌ Script not executable"
   ```

### 5.2 Documentation Verification
**Priority**: MEDIUM  
**Time**: 5 minutes

**Steps**:
1. Verify README updates
   ```bash
   # Check badges present
   grep -c "shields.io" README.md
   
   # Check npm installation is first
   grep -A5 "## Installation" README.md | grep -n "npm"
   
   # Check troubleshooting section exists
   grep -q "## Troubleshooting" README.md && echo "✅ Troubleshooting present" || echo "❌ Missing troubleshooting"
   ```

2. Verify CHANGELOG
   ```bash
   # Check bug is documented
   grep -q "ghs remove 1" CHANGELOG.md && echo "✅ Bug documented" || echo "❌ Bug not documented"
   
   # Check version matches
   grep -q "0.1.0" CHANGELOG.md && echo "✅ Version matches" || echo "❌ Version mismatch"
   ```

### 5.3 Final Checklist
**Priority**: HIGH  
**Time**: 5 minutes

**Decision points**:
1. [ ] Global install tested and working
2. [ ] Test count issue understood (205 vs 206)
3. [ ] All quality checks passing
4. [ ] package.json has no test dependencies
5. [ ] Bug is documented in CHANGELOG
6. [ ] README has npm badges and instructions
7. [ ] npm authentication verified (`npm whoami`)
8. [ ] No uncommitted changes except planned ones

## Execution Order

1. **First**: Test count investigation (understand the issue)
2. **Second**: Global installation testing (critical functionality)
3. **Third**: Package content validation (ensure correctness)
4. **Fourth**: Edge case testing (robustness)
5. **Fifth**: Complete validation checks
6. **Finally**: Make go/no-go decision for npm publish

## Success Criteria

- ✅ `npm install -g gh-switcher` works correctly
- ✅ `ghs` command available globally after install
- ✅ Understand why test count is 205 vs 206
- ✅ All files in package have correct permissions
- ✅ Package can be installed, used, and uninstalled cleanly
- ✅ No regressions from current shell-sourced version

## Time Estimate
Total: ~70 minutes to properly complete all missing steps

## Notes
- DO NOT publish until the "ghs remove 1" crash bug is fixed
- Consider creating a test npm account for practice publish
- Document any new issues found during testing