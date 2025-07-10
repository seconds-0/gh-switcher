#!/bin/bash
# Pre-commit hook for gh-switcher development
# Combines guard checks with CI checks

set -e

# First, run the guard checks if available
if [[ -x "./scripts/guard-hook.sh" ]]; then
    echo "🔒 Running guard checks..."
    if ! ./scripts/guard-hook.sh; then
        echo "❌ Guard checks failed!"
        exit 1
    fi
fi

echo "🚀 Running pre-commit CI checks..."

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "⚠️  npm not found, skipping CI checks"
    exit 0
fi

# Check if we're in the right directory
if [[ ! -f "gh-switcher.sh" ]] || [[ ! -f "package.json" ]]; then
    echo "⚠️  Not in gh-switcher root directory, skipping CI checks"
    exit 0
fi

# Allow skipping the CI check with environment variable
if [[ "${SKIP_CI_CHECK}" == "1" ]]; then
    echo "⚠️  Skipping CI checks (SKIP_CI_CHECK=1)"
    exit 0
fi

echo "📋 Running CI checks (lint + tests)..."

# Run the CI check
if npm run ci-check; then
    echo "✅ All CI checks passed!"
    exit 0
else
    echo "❌ CI checks failed!"
    echo ""
    echo "💡 To commit anyway (not recommended):"
    echo "   SKIP_CI_CHECK=1 git commit ..."
    echo ""
    echo "💡 To see what failed:"
    echo "   npm run lint       # Check for linting issues"
    echo "   npm test          # Run tests"
    echo ""
    exit 1
fi