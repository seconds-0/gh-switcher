#!/bin/bash

# Reset bash and zsh shells for testing gh-switcher
echo "🔄 Resetting bash and zsh shells for ghs testing..."

# Source gh-switcher in new bash shell
echo "📦 Testing bash shell..."
bash -c "source $(pwd)/gh-switcher.sh && echo '✅ Bash sourced successfully' && ghs"

echo ""

# Source gh-switcher in new zsh shell  
echo "📦 Testing zsh shell..."
zsh -c "source $(pwd)/gh-switcher.sh && echo '✅ Zsh sourced successfully' && ghs"

echo ""

# Reinstall GHS globally
echo "🔧 Reinstalling GHS globally..."
# Remove existing entries
sed -i.bak '/gh-switcher.sh/d' ~/.zshrc
# Add fresh entry
echo "source $(pwd)/gh-switcher.sh" >> ~/.zshrc
echo "✅ GHS reinstalled to ~/.zshrc"

echo ""
echo "✨ Shell reset complete. GHS is reinstalled and ready to use."