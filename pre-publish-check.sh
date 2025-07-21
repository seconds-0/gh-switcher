#!/bin/bash
set -e

# Trap errors for cleanup
trap 'echo "❌ Check failed at line $LINENO"' ERR

echo "🔍 Running pre-publish checks..."

echo "1️⃣ Lint check..."
npm run lint || { echo "❌ Lint failed"; exit 1; }

echo "2️⃣ Test suite..."
npm test || { echo "❌ Tests failed"; exit 1; }

echo "3️⃣ Build check..."
npm run build || { echo "❌ Build failed"; exit 1; }

echo "4️⃣ Git status..."
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Uncommitted changes:"
    git status --short
    echo "   Run 'git add .' and 'git commit' first"
    exit 1
fi

echo "5️⃣ Package content check..."
npm pack --dry-run > /dev/null || { echo "❌ Package creation failed"; exit 1; }

echo "6️⃣ Verify required files..."
[[ -f LICENSE ]] || { echo "❌ LICENSE file missing"; exit 1; }
[[ -f README.md ]] || { echo "❌ README.md missing"; exit 1; }
[[ -f gh-switcher.sh ]] || { echo "❌ Main script missing"; exit 1; }
[[ -x gh-switcher.sh ]] || { echo "❌ Main script not executable"; exit 1; }

echo "7️⃣ Verify package.json..."
# Check no placeholders remain
if grep -E "REPLACE_WITH|Your Name|your\.email" package.json; then
    echo "❌ Placeholders found in package.json!"
    exit 1
fi

# Check required fields
for field in name version description author license; do
    if ! npx json -f package.json $field >/dev/null 2>&1; then
        echo "❌ Missing field: $field"
        exit 1
    fi
done

echo "8️⃣ Run security audit..."
echo "Running npm audit to check for vulnerabilities..."
if npm audit --audit-level=moderate; then
    echo "✅ No security vulnerabilities found"
else
    echo "⚠️  Security vulnerabilities detected. Consider running 'npm audit fix'"
    echo "   Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Publish aborted due to security concerns"
        exit 1
    fi
fi

echo "9️⃣ Verify npm authentication..."
if ! npm whoami >/dev/null 2>&1; then
    echo "❌ Not logged into npm. Run 'npm login' first"
    exit 1
fi

echo ""
echo "✅ All pre-publish checks passed!"
echo "📦 Package ready for: npm publish"
echo ""
echo "✅ Package ready for release!"