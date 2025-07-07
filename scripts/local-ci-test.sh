#!/usr/bin/env bash

# Local CI Test Script
# Simulates GitHub Actions CI environment for gh-switcher

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# CI simulation settings
CI_SHELLS=("bash" "zsh")
CI_NODE_VERSION="18"
TEST_TIMEOUT=300  # 5 minutes timeout like CI

echo -e "${BLUE}🔧 Local CI Test Suite for gh-switcher${NC}"
echo "=================================================="

# Function to run command with timeout
run_with_timeout() {
    local timeout_duration=$1
    shift
    timeout "$timeout_duration" "$@"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    
    # Check required tools
    local required_tools=("node" "npm" "git" "shellcheck" "bats")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${RED}❌ Missing required tool: $tool${NC}"
            exit 1
        else
            echo -e "${GREEN}✅ $tool: $(command -v "$tool")${NC}"
        fi
    done
    
    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ "$node_version" -lt "$CI_NODE_VERSION" ]]; then
        echo -e "${YELLOW}⚠️  Node.js version $node_version may differ from CI (expects $CI_NODE_VERSION)${NC}"
    fi
    
    # Check git config
    if ! git config --get user.name >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Git user.name not configured (may affect tests)${NC}"
    fi
    
    echo ""
}

# Function to run in clean environment
run_clean_test() {
    local shell_name=$1
    echo -e "${BLUE}🧪 Testing with $shell_name in clean environment...${NC}"
    
    # Create isolated test environment
    local test_dir=$(mktemp -d)
    local original_pwd=$(pwd)
    
    # Copy project to test directory
    cp -r . "$test_dir/"
    cd "$test_dir"
    
    # Clean any existing node_modules or test artifacts
    rm -rf node_modules .npm
    rm -rf tests/tmp* /tmp/gh-switcher-test-*
    
    # Run tests in the specific shell
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    if ! run_with_timeout "$TEST_TIMEOUT" npm install --ignore-scripts --no-audit --no-fund; then
        echo -e "${RED}❌ npm install failed${NC}"
        cd "$original_pwd"
        rm -rf "$test_dir"
        return 1
    fi
    
    echo -e "${YELLOW}🔍 Running lint...${NC}"
    if ! run_with_timeout "$TEST_TIMEOUT" npm run lint; then
        echo -e "${RED}❌ Lint failed with $shell_name${NC}"
        cd "$original_pwd"
        rm -rf "$test_dir"
        return 1
    fi
    
    echo -e "${YELLOW}🧪 Running tests...${NC}"
    if ! run_with_timeout "$TEST_TIMEOUT" "$shell_name" -c "npm test"; then
        echo -e "${RED}❌ Tests failed with $shell_name${NC}"
        cd "$original_pwd"
        rm -rf "$test_dir"
        return 1
    fi
    
    echo -e "${GREEN}✅ All tests passed with $shell_name${NC}"
    
    # Cleanup
    cd "$original_pwd"
    rm -rf "$test_dir"
    return 0
}

# Function to simulate CI environment variables
setup_ci_environment() {
    echo -e "${BLUE}🌍 Setting up CI-like environment...${NC}"
    
    # Set CI-like environment variables
    export CI=true
    export GITHUB_ACTIONS=true
    export RUNNER_OS="$(uname -s)"
    export RUNNER_TEMP="/tmp"
    export GITHUB_WORKSPACE="$(pwd)"
    
    # Unset variables that might interfere
    unset GH_PROJECT_CONFIG
    unset GH_USERS_CONFIG 
    unset GH_USER_PROFILES
    
    # Set stricter shell options like CI
    set -euo pipefail
    
    echo -e "${GREEN}✅ CI environment configured${NC}"
    echo ""
}

# Function to run permission tests
test_permissions() {
    echo -e "${BLUE}🔒 Testing file permissions...${NC}"
    
    # Check script permissions
    if [[ ! -x "gh-switcher.sh" ]]; then
        echo -e "${RED}❌ gh-switcher.sh is not executable${NC}"
        return 1
    fi
    
    # Check test file permissions
    find tests -name "*.bats" -type f | while read -r test_file; do
        if [[ ! -r "$test_file" ]]; then
            echo -e "${RED}❌ Test file not readable: $test_file${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ All file permissions correct${NC}"
    echo ""
}

# Function to test concurrent execution
test_concurrent_execution() {
    echo -e "${BLUE}🔀 Testing concurrent execution...${NC}"
    
    # Run multiple test instances in parallel (simulates CI parallelism)
    local pids=()
    
    for i in {1..3}; do
        (
            export TEST_INSTANCE="$i"
            npm test >/dev/null 2>&1
        ) &
        pids+=($!)
    done
    
    # Wait for all to complete
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed=1
        fi
    done
    
    if [[ $failed -eq 1 ]]; then
        echo -e "${RED}❌ Concurrent execution failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Concurrent execution successful${NC}"
    echo ""
}

# Function to check for CI-specific issues
check_ci_issues() {
    echo -e "${BLUE}🔍 Checking for common CI issues...${NC}"
    
    # Check for hardcoded paths
    if grep -r "/Users/" . --exclude-dir=node_modules --exclude-dir=.git >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found potential hardcoded paths${NC}"
        grep -r "/Users/" . --exclude-dir=node_modules --exclude-dir=.git | head -5
    fi
    
    # Check for macOS-specific commands
    if grep -r "brew\|darwin\|macos" . --exclude-dir=node_modules --exclude-dir=.git >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found potential macOS-specific references${NC}"
        grep -r "brew\|darwin\|macos" . --exclude-dir=node_modules --exclude-dir=.git | head -5
    fi
    
    # Check for unset variables
    if grep -r '\$[A-Z_]*[^{]' gh-switcher.sh | grep -v '${.*}' >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Found potential unquoted variables${NC}"
        grep -r '\$[A-Z_]*[^{]' gh-switcher.sh | grep -v '${.*}' | head -5
    fi
    
    echo -e "${GREEN}✅ CI issue check completed${NC}"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Local CI Test Suite${NC}"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Setup CI environment
    setup_ci_environment
    
    # Test permissions
    test_permissions
    
    # Check for CI-specific issues
    check_ci_issues
    
    # Run tests in different shells
    local overall_success=0
    
    for shell in "${CI_SHELLS[@]}"; do
        if command -v "$shell" >/dev/null 2>&1; then
            echo -e "${BLUE}📋 Testing with $shell...${NC}"
            if run_clean_test "$shell"; then
                echo -e "${GREEN}✅ $shell tests passed${NC}"
            else
                echo -e "${RED}❌ $shell tests failed${NC}"
                overall_success=1
            fi
        else
            echo -e "${YELLOW}⚠️  $shell not available, skipping${NC}"
        fi
        echo ""
    done
    
    # Test concurrent execution
    test_concurrent_execution
    
    # Final summary
    echo "=================================================="
    if [[ $overall_success -eq 0 ]]; then
        echo -e "${GREEN}🎉 All local CI tests passed!${NC}"
        echo -e "${GREEN}✅ Ready for CI deployment${NC}"
    else
        echo -e "${RED}❌ Some local CI tests failed${NC}"
        echo -e "${RED}🔧 Fix issues before pushing to CI${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 