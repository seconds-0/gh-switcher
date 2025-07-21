# 🎯 GitHub Project Switcher (gh-switcher)

[![npm version](https://img.shields.io/npm/v/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
[![npm downloads](https://img.shields.io/npm/dm/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Lightweight, secure GitHub account switcher for the command line. Manage multiple GitHub accounts (personal, work, client) with project-specific memory and numbered user references for easy switching.

## Features

- 🔢 **Numbered Users**: Reference users by simple numbers (1, 2, 3) instead of usernames
- 📁 **Project Memory**: Projects remember their associated GitHub account
- 🎯 **Smart Dashboard**: Running `ghs` shows current status and available actions
- ⚡ **Simple Commands**: `ghs switch 2`, `ghs assign 1`, etc.
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
# 1. Authenticate with GitHub CLI (if not already done)
gh auth login

# 2. Add your current GitHub account
ghs add current

# 3. You're ready to go!
ghs             # Shows current status

# Add more accounts as needed
ghs add alice --name "Alice Smith" --email "alice@work.com"
ghs add work --host github.company.com  # Enterprise account

# Switch between accounts by number
ghs switch 1    # Switch to first account
ghs switch 2    # Switch to second account

# Assign account to current project
ghs assign 1    # Use account 1 for this project

# Enable automatic switching (one-time setup)
ghs auto-switch enable    # Switch accounts automatically when entering directories
```

## Commands

### Daily Workflow

- `ghs` - Show smart dashboard with current status
- `ghs switch <number>` - Switch to user by number
- `ghs assign <number>` - Assign user as project default

### Auto-Switch (Directory-Based)

- `ghs auto-switch enable` - Turn on automatic switching when entering directories
- `ghs auto-switch disable` - Turn off automatic switching
- `ghs auto-switch status` - Show current auto-switch configuration
- `ghs auto-switch test` - Preview what would happen in current directory

### User Management

- `ghs add <username|current>` - Add a new GitHub user
- `ghs add current` - Add currently authenticated GitHub user
- `ghs add <user> --ssh-key <path>` - Add user with SSH key
- `ghs add <user> --host github.company.com` - Add enterprise user
- `ghs users` - Show numbered list of users
- `ghs remove <user>` - Remove user by name or number
- `ghs profiles` - Show user profiles (add `--verbose` for detailed view)
- `ghs update <user> <field> "<value>"` - Update profile field (name, email, gpg)
- `ghs validate [user]` - Run profile validation check

### Project & Status & Help

- `ghs status` - Show detailed current status
- `ghs list` - List all configured projects
- `ghs help` - Display full reference of all commands
- `ghs install` - Install to shell profile
- `ghs uninstall` - Remove from shell profile

## Profile Format

gh-switcher uses a simple v3 profile format:

```
username:name:email[:gpg_key][:auto_sign]
```

All fields are plain text (no base64 encoding). GPG key and auto-sign are optional.

### Examples

```bash
# Add user with all fields
ghs add-user alice --name "Alice Smith" --email "alice@work.com" --gpg "ABC123DEF" --auto-sign true

# Add minimal user (auto-detects from git config)
ghs add-user bob --email "bob@personal.com"

# Update specific fields
ghs update alice email "alice@newcompany.com"
ghs update bob gpg "XYZ789GHI"
```

## Configuration Files

- `~/.gh-users` - List of usernames (one per line)
- `~/.gh-user-profiles` - Enhanced profile data (v3 format)
- `~/.gh-project-accounts` - Project to account mapping

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) - for authentication
- Git - for repository operations
- **Bash** (4.0+) - Required (gh-switcher uses bash-specific features)
- Supported shells:
  - **Bash** - Full native support
  - **Zsh** - Full native support  
  - **Fish** - Via wrapper function ([setup guide](docs/FISH_SETUP.md))
  - **Git Bash (Windows)** - Full support ([Windows users guide](docs/WINDOWS_USERS.md))
  - Works in **VS Code integrated terminal**
- Not supported:
  - **PowerShell** - gh-switcher is a bash script ([Windows users guide](docs/WINDOWS_USERS.md))
  - **Dash/POSIX sh** - Requires bash features ([POSIX shell guide](docs/POSIX_SHELL_USAGE.md))

## Development Setup (Contributors)

To run linting and the BATS test-suite locally you need two extra tools:

```bash
# macOS (Homebrew)
brew install shellcheck bats-core

# Debian/Ubuntu (22.04+ ships bats-core ≥1.7)
sudo apt-get update && sudo apt-get install -y shellcheck bats
# For newer BATS on older Ubuntu: sudo add-apt-repository ppa:duggiefresh/bats && sudo apt-get install bats-core
```

Once installed:

```bash
npm run lint      # ShellCheck on gh-switcher.sh
npm test          # Runs all BATS specs under tests/
npm run ci-check  # Quick CI validation (recommended before pushing)
npm run ci-test   # Comprehensive CI simulation (full environment testing)
```

> These tools are **development-only**; end-users who install `gh-switcher` via
> curl or `npm install -g` do **not** need them.

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
