#!/bin/bash
# Developer pre-commit hook for gh-switcher
# Runs essential checks quickly

set -e

echo "🚀 Running pre-commit checks..."

# Allow skipping with environment variable
if [[ "${SKIP_CHECKS}" == "1" ]]; then
    echo "⚠️  Skipping pre-commit checks (SKIP_CHECKS=1)"
    exit 0
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "⚠️  npm not found, skipping checks"
    exit 0
fi

# Run lint
echo "📋 Running ShellCheck..."
if ! npm run lint --silent; then
    echo "❌ Linting failed!"
    echo "💡 Fix issues with: npm run lint"
    exit 1
fi

# Run tests
echo "📋 Running tests..."
if ! npm test --silent; then
    echo "❌ Tests failed!"
    echo "💡 See failures with: npm test"
    exit 1
fi

echo "✅ All checks passed!"
exit 0