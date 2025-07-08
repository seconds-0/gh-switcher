#!/bin/bash

# 🎯 gh-switcher Guard Hook
# Validates GitHub account and git profile before committing to prevent wrong-account commits
# 
# Installation:
#   ghs guard install    # Recommended
#   # Or manually: ln -sf "$(pwd)/scripts/guard-hook.sh" .git/hooks/pre-commit
#
# Override (bypass validation):
#   GHS_SKIP_HOOK=1 git commit -m "message"

set -euo pipefail

# Exit early if hook is disabled
if [[ "${GHS_SKIP_HOOK:-}" == "1" ]]; then
    exit 0
fi

# Source the main gh-switcher script to use its functions
# Try multiple possible locations for gh-switcher.sh
if [[ -n "${GH_SWITCHER_PATH:-}" && -f "$GH_SWITCHER_PATH" ]]; then
    # Use provided path
    :
elif [[ -f "$(dirname "$0")/../gh-switcher.sh" ]]; then
    # Relative to scripts directory
    GH_SWITCHER_PATH="$(dirname "$0")/../gh-switcher.sh"
elif [[ -f "$(git rev-parse --show-toplevel)/gh-switcher.sh" ]]; then
    # At git repository root
    GH_SWITCHER_PATH="$(git rev-parse --show-toplevel)/gh-switcher.sh"
elif command -v ghs >/dev/null 2>&1; then
    # Try to find via ghs command
    GH_SWITCHER_PATH="$(which ghs 2>/dev/null || echo "")"
else
    echo "⚠️  gh-switcher script not found"
    echo "   Set GH_SWITCHER_PATH environment variable or install gh-switcher"
    exit 0  # Don't block commit if gh-switcher not available
fi

if [[ ! -f "$GH_SWITCHER_PATH" ]]; then
    echo "⚠️  gh-switcher script not found at $GH_SWITCHER_PATH"
    echo "   Set GH_SWITCHER_PATH environment variable or install gh-switcher"
    exit 0  # Don't block commit if gh-switcher not available
fi

# Source gh-switcher functions
source "$GH_SWITCHER_PATH"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Get current project name
PROJECT=$(basename "$PWD")

echo -e "${BLUE}🛡️  gh-switcher pre-commit validation${NC}"
echo "📁 Project: $PROJECT"

# Check GitHub CLI authentication
if ! check_gh_auth; then
    echo -e "${YELLOW}⚠️  GitHub CLI not authenticated${NC}"
    echo "   This commit will proceed but account validation skipped"
    echo "   Run 'gh auth login' to enable validation"
    exit 0
fi

# Get current GitHub user
CURRENT_GH_USER=$(get_current_github_user)
if [[ -z "$CURRENT_GH_USER" ]]; then
    echo -e "${YELLOW}⚠️  Could not determine current GitHub user${NC}"
    echo "   This commit will proceed but account validation skipped"
    exit 0
fi

echo "👤 Current GitHub user: $CURRENT_GH_USER"

# Check if there's a project assignment
PROJECT_USER=""
if [[ -f "$GH_PROJECT_CONFIG" ]]; then
    PROJECT_USER=$(grep "^$PROJECT=" "$GH_PROJECT_CONFIG" 2>/dev/null | cut -d'=' -f2 || echo "")
fi

# Get current git config
GIT_CONFIG_OUTPUT=$(detect_git_config "local" 2>/dev/null)
GIT_NAME=$(echo "$GIT_CONFIG_OUTPUT" | grep "^name:" | cut -d':' -f2- || echo "")
GIT_EMAIL=$(echo "$GIT_CONFIG_OUTPUT" | grep "^email:" | cut -d':' -f2- || echo "")

# If no local git config, check global
if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    GIT_CONFIG_OUTPUT=$(detect_git_config "global" 2>/dev/null)
    GIT_NAME=$(echo "$GIT_CONFIG_OUTPUT" | grep "^name:" | cut -d':' -f2- || echo "")
    GIT_EMAIL=$(echo "$GIT_CONFIG_OUTPUT" | grep "^email:" | cut -d':' -f2- || echo "")
fi

echo "📧 Git config: $GIT_NAME <$GIT_EMAIL>"

# Validation logic
VALIDATION_FAILED=0

# Check 1: Project assignment mismatch
if [[ -n "$PROJECT_USER" ]]; then
    echo "🔗 Project assigned to: $PROJECT_USER"
    
    if [[ "$CURRENT_GH_USER" != "$PROJECT_USER" ]]; then
        echo -e "${RED}❌ GitHub account mismatch!${NC}"
        echo "   Current user: $CURRENT_GH_USER"
        echo "   Project assigned to: $PROJECT_USER"
        echo "   Run 'ghs switch <number>' to switch accounts"
        echo "   Or run 'ghs assign <number>' to update project assignment"
        VALIDATION_FAILED=1
    else
        echo -e "${GREEN}✅ GitHub account matches project assignment${NC}"
    fi
else
    echo -e "${YELLOW}💡 No project assignment found${NC}"
    echo "   Run 'ghs assign <number>' to set default account for this project"
fi

# Check 2: Git config validation
if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    echo -e "${RED}❌ Git config incomplete!${NC}"
    echo "   Missing name or email in git config"
    echo "   Run 'git config user.name \"Your Name\"'"
    echo "   Run 'git config user.email \"your@email.com\"'"
    VALIDATION_FAILED=1
else
    # Check if git config matches a known profile
    if [[ -n "$CURRENT_GH_USER" ]]; then
        PROFILE_DATA=$(get_user_profile "$CURRENT_GH_USER" 2>/dev/null || echo "")
        if [[ -n "$PROFILE_DATA" ]]; then
            PROFILE_NAME=$(echo "$PROFILE_DATA" | grep "^name:" | cut -d':' -f2- || echo "")
            PROFILE_EMAIL=$(echo "$PROFILE_DATA" | grep "^email:" | cut -d':' -f2- || echo "")
            
            if [[ -n "$PROFILE_NAME" && -n "$PROFILE_EMAIL" ]]; then
                if [[ "$GIT_NAME" == "$PROFILE_NAME" && "$GIT_EMAIL" == "$PROFILE_EMAIL" ]]; then
                    echo -e "${GREEN}✅ Git config matches profile${NC}"
                else
                    echo -e "${YELLOW}⚠️  Git config doesn't match profile${NC}"
                    echo "   Profile: $PROFILE_NAME <$PROFILE_EMAIL>"
                    echo "   Git config: $GIT_NAME <$GIT_EMAIL>"
                    echo "   Run 'ghs switch <number>' to update git config"
                    # This is a warning, not a failure
                fi
            fi
        fi
    fi
fi

# Handle validation results
if [[ $VALIDATION_FAILED -eq 1 ]]; then
    echo ""
    echo -e "${RED}🚫 Pre-commit validation failed${NC}"
    echo "   Fix the issues above before committing"
    echo ""
    echo "To bypass this validation (not recommended):"
    echo "   GHS_SKIP_HOOK=1 git commit -m \"your message\""
    echo ""
    exit 1
fi

# Success
echo -e "${GREEN}✅ Pre-commit validation passed${NC}"
echo "   Ready to commit with correct account and profile"
echo ""
exit 0