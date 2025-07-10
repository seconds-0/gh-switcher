#!/bin/bash
# Install developer pre-commit hooks for gh-switcher

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "🔧 Installing developer pre-commit hooks..."

# Check if we're in a git repository
if [[ ! -d "$REPO_ROOT/.git" ]]; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Backup existing pre-commit hook if it exists and isn't our hook
if [[ -e "$HOOKS_DIR/pre-commit" ]] || [[ -L "$HOOKS_DIR/pre-commit" ]]; then
    if ! grep -q "pre-commit-dev.sh" "$HOOKS_DIR/pre-commit" 2>/dev/null; then
        backup_name="$HOOKS_DIR/pre-commit.backup.$(date +%s)"
        echo "📦 Backing up existing pre-commit hook to: $backup_name"
        mv "$HOOKS_DIR/pre-commit" "$backup_name"
    fi
fi

# Create the pre-commit hook that calls our script
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Auto-generated pre-commit hook for gh-switcher development

# Find the repository root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Run the developer pre-commit script
if [[ -x "$REPO_ROOT/scripts/pre-commit-dev.sh" ]]; then
    "$REPO_ROOT/scripts/pre-commit-dev.sh"
else
    echo "⚠️  Developer pre-commit script not found"
    exit 0
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Developer pre-commit hook installed!"
echo ""
echo "The hook will run before each commit to:"
echo "  - Check code with ShellCheck"
echo "  - Run all tests"
echo ""
echo "To skip checks for a single commit:"
echo "  SKIP_CHECKS=1 git commit ..."
echo ""
echo "To uninstall:"
echo "  rm .git/hooks/pre-commit"
echo ""