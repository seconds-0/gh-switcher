#\!/bin/bash
set -euo pipefail

# Set up VS Code Git environment
export TERM_PROGRAM=vscode
export VSCODE_GIT_IPC_HANDLE='/tmp/vscode-git-$$'
export VSCODE_GIT_ASKPASS_NODE='/usr/local/bin/node'
export VSCODE_GIT_ASKPASS_MAIN='$HOME/.vscode/extensions/git/dist/askpass-main.js'
export GIT_ASKPASS='$HOME/.vscode/extensions/git/askpass.sh'

source '/Users/alexanderhuth/Code/gh-switcher/gh-switcher.sh'

# Create a test git repo first
test_repo=$(mktemp -d)
cd "$test_repo"
git init >/dev/null 2>&1

# Add user first
ghs add gituser >/dev/null 2>&1

# Update the profile with our test data
ghs edit gituser --name 'Git User' --email 'git@vscode.test' >/dev/null 2>&1

# Switch to user - this should apply the profile
ghs switch gituser >/dev/null 2>&1

# Debug: show what profiles exist
echo "Profiles in file:" >&2
cat "$GH_USER_PROFILES" >&2

# Verify git config was updated
git_name=$(git config user.name)
git_email=$(git config user.email)

if [[ "$git_name" \!= 'Git User' ]]; then
    echo "ERROR: Git name not set correctly: '$git_name'" >&2
    echo "Git config user.name: $(git config --list | grep user.name)" >&2
    exit 1
fi

if [[ "$git_email" \!= 'git@vscode.test' ]]; then
    echo "ERROR: Git email not set correctly: '$git_email'" >&2
    exit 1
fi

# Clean up
cd /
rm -rf "$test_repo"

echo 'Git config updated correctly'
