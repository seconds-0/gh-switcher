#!/bin/bash
set -e

echo "🔍 Checking NPM publishing prerequisites..."

# Function to check command exists
check_command() {
    local cmd=$1
    local min_version=$2
    local install_url=$3
    
    # Validate command parameter to prevent injection
    if [[ ! "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ Invalid command name: $cmd"
        return 1
    fi
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd is required but not installed"
        echo "   Install from: $install_url"
        return 1
    else
        echo "✅ $cmd found: $(command -v "$cmd")"
        if [[ -n "$min_version" ]]; then
            # Use safer version extraction
            local version
            version=$(command "$cmd" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            echo "   Version: $version (minimum: $min_version)"
        fi
    fi
}

# Check Node.js
check_command node "14.0.0" "https://nodejs.org/"

# Check npm
check_command npm "6.0.0" "Comes with Node.js"

# Check npx
check_command npx "" "Comes with npm 5.2+"

# Check git
check_command git "" "https://git-scm.com/"

# Check for json package (used in many commands)
if ! npx json --version >/dev/null 2>&1; then
    echo "⚠️  json package not found globally"
    echo "   Would you like to install it? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing json package globally..."
        npm install -g json
        echo "✅ json package installed"
    else
        echo "⚠️  json package not installed - some commands may not work"
    fi
else
    echo "✅ json package available"
fi

# Check Docker (optional but recommended)
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker found (optional, for cross-platform testing)"
else
    echo "⚠️  Docker not found (optional, needed for Linux testing)"
fi

# Check shell
echo "📍 Current shell: $SHELL"

# Check for potential conflicts
if type ghs >/dev/null 2>&1; then
    echo "⚠️  Warning: 'ghs' command already exists at: $(which ghs)"
    echo "   This may conflict with gh-switcher installation"
fi

echo ""
echo "✅ Prerequisites check complete!"