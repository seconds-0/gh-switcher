#!/usr/bin/env bash

# Quick CI Check Script for gh-switcher
# Run this before pushing to ensure CI will pass

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick CI Check for gh-switcher${NC}"
echo "=================================="

# Function to run a check and report results
run_check() {
    local check_name="$1"
    local check_command="$2"
    
    echo -e "${YELLOW}📋 $check_name...${NC}"
    
    if eval "$check_command"; then
        echo -e "${GREEN}✅ $check_name passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $check_name failed${NC}"
        return 1
    fi
}

# Main checks
main() {
    local failed_checks=0
    
    # Check 1: Lint
    if ! run_check "ShellCheck Lint" "npm run lint"; then
        ((failed_checks++))
    fi
    
    # Check 2: Tests with CI environment
    if ! run_check "Tests (CI mode)" "CI=true GITHUB_ACTIONS=true npm test"; then
        ((failed_checks++))
    fi
    
    # Check 3: Bash compatibility
    if ! run_check "Bash Compatibility" "bash -c 'set -euo pipefail && npm test > /dev/null 2>&1'"; then
        ((failed_checks++))
    fi
    
    # Check 4: Clean temporary files
    if ! run_check "Clean Temp Files" "find /tmp -name 'gh-switcher-test-*' -type d 2>/dev/null | wc -l | grep -q '^0$' || { find /tmp -name 'gh-switcher-test-*' -type d -exec rm -rf {} + 2>/dev/null; true; }"; then
        ((failed_checks++))
    fi
    
    echo "=================================="
    
    if [[ $failed_checks -eq 0 ]]; then
        echo -e "${GREEN}🎉 All checks passed! Ready for CI${NC}"
        echo -e "${GREEN}✅ You can push to GitHub with confidence${NC}"
        exit 0
    else
        echo -e "${RED}❌ $failed_checks check(s) failed${NC}"
        echo -e "${RED}🔧 Fix issues before pushing to GitHub${NC}"
        exit 1
    fi
}

main "$@" 