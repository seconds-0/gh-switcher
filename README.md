# 🎯 GitHub Project Switcher (gh-switcher)

[![npm version](https://img.shields.io/npm/v/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
[![npm downloads](https://img.shields.io/npm/dm/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Lightweight, secure GitHub account switcher for the command line. Manage multiple GitHub accounts (personal, work, client) with project-specific memory and numbered user references for easy switching.

## Why gh-switcher?

If you manage multiple GitHub accounts (personal, work, clients), you've probably:
- 🤦 Accidentally pushed commits with the wrong email/identity
- 😤 Struggled with SSH key conflicts between accounts  
- 🔄 Constantly switched git configs manually
- 🚫 Had commits rejected due to signing key mismatches

**gh-switcher solves all of this** with numbered shortcuts and project memory.

## Features

- 🔢 **Numbered Shortcuts**: Reference accounts by number OR name (e.g., `ghs switch 1` or `ghs switch work`)
- 📁 **Project Memory**: Projects remember their assigned GitHub account
- 🔑 **SSH Key Management**: Automatically manages and validates SSH keys per account
- 🛡️ **Guard Hooks**: Pre-commit protection prevents pushing with wrong identity
- 🎯 **Status Overview**: Running `ghs` shows current account, project assignment, and SSH status
- 🔐 **Enhanced Profiles**: Store name, email, GPG keys, and auto-sign preferences
- 🤖 **Automation-Friendly**: All commands work non-interactively for scripting

## Installation

### Via npm (Recommended)
```bash
npm install -g gh-switcher
```

After installation, the `ghs` command will be available globally.

### Prerequisites
Before installing gh-switcher, ensure you have:
- **Node.js** (v14 or higher) - [Installation guide](https://nodejs.org/)
- **Git** - [Installation guide](https://git-scm.com/downloads)
- **GitHub CLI** (`gh`) - [Installation guide](https://cli.github.com/manual/installation)

Verify prerequisites:
```bash
node --version   # Should show v14.0.0 or higher
git --version    # Should show git version
gh --version     # Should show gh version
```

### Platform Support
- ✅ **macOS**: Full support
- ✅ **Linux**: Full support  
- ⚠️  **Windows**: Requires Git Bash or WSL (not native CMD/PowerShell)

### Manual Installation

For **Bash/Zsh** users:
```bash
# Download and make executable
curl -o gh-switcher.sh https://raw.githubusercontent.com/seconds-0/gh-switcher/main/gh-switcher.sh
chmod +x gh-switcher.sh

# Add to your shell profile
echo "source $(pwd)/gh-switcher.sh" >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc  # or source ~/.bashrc
```

For **Fish** users: Run `ghs fish-setup` after installation, or see [Fish Setup Guide](docs/FISH_SETUP.md).

## Quick Start

```bash
# 1. Add your GitHub accounts
ghs add current                                    # Add current gh auth user
ghs add work --email "you@company.com"            # Add work account

# 2. See your numbered accounts
ghs users
# 1. personal (you@gmail.com)
# 2. work (you@company.com)

# 3. Assign accounts to projects
cd ~/projects/personal-blog && ghs assign 1      # Personal projects use account 1
cd ~/projects/work-app && ghs assign 2           # Work projects use account 2

# Optional but recommended:
ghs guard install                                 # Prevent wrong account commits
ghs auto-switch enable                            # Auto-switch when entering directories

# Now just work normally - gh-switcher handles the rest!
ghs                                               # Check current status anytime
```

## Commands

### Essential Commands
- `ghs` - Show current user and project status
- `ghs switch <number|name>` - Switch GitHub account (e.g., `ghs switch 2` or `ghs switch work`)
- `ghs assign <number|name>` - Set project's default account
- `ghs users` - List all accounts with numbers

### Account Management  
- `ghs add <name>` - Add new account (`current` for active gh user)
- `ghs remove <number|name>` - Remove account
- `ghs edit <user>` - Update email, SSH key, or host settings
- `ghs show <user>` - View account details and diagnose issues

### Advanced Features
- `ghs guard install` - Install pre-commit hook (prevents wrong account commits)
- `ghs guard uninstall` - Remove pre-commit hook
- `ghs guard test` - Test guard validation without committing
- `ghs auto-switch enable` - Auto-switch accounts by directory
- `ghs auto-switch disable` - Turn off auto-switching
- `ghs test-ssh [<user>]` - Verify SSH key works with GitHub
- `ghs doctor` - Show diagnostics for troubleshooting

Run `ghs help` for complete command reference.


## Configuration

gh-switcher stores its config in your home directory:
- `~/.gh-users` - Your GitHub accounts
- `~/.gh-project-accounts` - Project ↔ account mappings

All managed automatically - you never need to edit these.


## Performance

- Commands complete in <100ms (enforced by automated benchmarks)
- Optimized for minimal network calls and fast switching
- Caches GitHub API responses for better performance

## Automation & Scripting

All commands are designed to work non-interactively:

```bash
# Script example
for project in project1 project2 project3; do
  cd "$project"
  ghs assign work-account
  git push
done
```

## Troubleshooting

### npm Installation Issues

**Permission denied (EACCES) during global install**:
```bash
# Option 1: Configure npm to use a different directory (recommended)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc  # or source ~/.bashrc
npm install -g gh-switcher
```

**Command not found after installation**:
```bash
# Check npm global bin location
npm config get prefix
# Add to PATH if needed
export PATH="$(npm config get prefix)/bin:$PATH"
```

**Existing command conflicts**:
```bash
# Check if ghs already exists
which ghs
# If it exists, uninstall conflicting package first
```

**Windows-specific issues**:
- Must use Git Bash or WSL, not Command Prompt or PowerShell
- Git Bash minimum version: 2.32.0
- Run `npm install -g gh-switcher --force` if symlink issues occur

**npm Registry Issues**:
- Timeout errors: `npm config set registry https://registry.npmjs.org/`
- Corporate proxy: See npm docs for proxy configuration
- Use `npm install -g gh-switcher --verbose` for detailed error logs

**Verify installation**:
```bash
npm list -g gh-switcher  # Should show the package
which ghs                # Should show path to command
ghs --version           # Should show version
```

## Contributing

See [CHANGELOG.md](CHANGELOG.md) for recent changes and [docs/ROADMAP.md](docs/ROADMAP.md) for future plans.

## License

MIT License - see [LICENSE](LICENSE) file.
