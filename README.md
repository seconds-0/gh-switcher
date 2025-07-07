# 🎯 GitHub Project Switcher (gh-switcher)

Lightweight, secure GitHub account switcher for the command line. Manage multiple GitHub accounts (personal, work, client) with project-specific memory and numbered user references for easy switching.

## Features

- 🔢 **Numbered Users**: Reference users by simple numbers (1, 2, 3) instead of usernames
- 📁 **Project Memory**: Projects remember their associated GitHub account
- 🎯 **Smart Dashboard**: Running `ghs` shows current status and available actions
- ⚡ **Simple Commands**: `ghs switch 2`, `ghs assign 1`, etc.
- 🔐 **Enhanced Profiles**: Store name, email, GPG keys, and auto-sign preferences
- 🤖 **Automation-Friendly**: All commands work non-interactively for scripting

## Installation

### Quick Install

```bash
# Download and make executable
curl -o gh-switcher.sh https://raw.githubusercontent.com/user/repo/main/gh-switcher.sh
chmod +x gh-switcher.sh

# Install to your shell profile
./gh-switcher.sh install
```

### Manual Install

```bash
# Add to your shell profile
echo "source $(pwd)/gh-switcher.sh" >> ~/.zshrc
source ~/.zshrc
```

## Quick Start

```bash
# Add your GitHub accounts
ghs add-user alice --name "Alice Smith" --email "alice@work.com"
ghs add-user bob --name "Bob Jones" --email "bob@personal.com"

# Switch between accounts by number
ghs switch 1    # Switch to alice
ghs switch 2    # Switch to bob

# Assign account to current project
ghs assign 1    # Use alice for this project

# View dashboard
ghs             # Shows current status and quick actions
```

## Commands

### Daily Workflow

- `ghs` - Show smart dashboard with current status
- `ghs switch <number>` - Switch to user by number
- `ghs assign <number>` - Assign user as project default

### User Management

- `ghs add-user <username>` - Add user with profile fields
- `ghs add-user current` - Add currently authenticated GitHub user
- `ghs add-user <user> --name "Name" --email "email@domain" --gpg <key> --auto-sign true --force`
- `ghs users` - Show numbered list of users
- `ghs remove-user <user>` - Remove user by name or number
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
- Bash/Zsh shell

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

## Contributing

See [CHANGELOG.md](CHANGELOG.md) for recent changes and [docs/ROADMAP.md](docs/ROADMAP.md) for future plans.

## License

MIT License - see [LICENSE](LICENSE) file.
