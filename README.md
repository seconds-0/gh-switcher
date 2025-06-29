# 🎯 GitHub Project Switcher

A lightweight, secure solution for project-specific GitHub account switching.

## Why This Tool?

When working on multiple projects with different GitHub accounts (personal, work, clients), you face three problems:
1. **Forgetting usernames**: Hard to remember exact GitHub usernames (was it `work-user` or `work-username`?)
2. **Forgetting which account goes with which project**: Easy to accidentally push to the wrong account
3. **Not knowing what's available**: What accounts do I have? What can I do right now?

This tool solves all three problems with **numbered users**, **project-specific memory**, and a **smart dashboard** that shows you exactly what you need to know.

## Installation

### 🎯 Super Easy Install

Clone and install in one command:

```bash
git clone https://github.com/alexthuth/gh-switcher.git
cd gh-switcher
./gh-switcher.sh install
```

**That's it!** The install command auto-detects your shell (zsh/bash) and adds the switcher to your profile.

**Alternative installation methods:**
```bash
# Using npm script
npm run install-global

# Manual shell profile setup
echo "source $(pwd)/gh-switcher.sh" >> ~/.zshrc && source ~/.zshrc
```

After installation, restart your terminal or run `source ~/.zshrc`, then use `ghs` anywhere!

## Usage

### 🚀 Super Easy Way: Numbered Users

```bash
# First, add your users to get numbered IDs
ghs add-user alexthuth
ghs add-user work-account
# ✅ Added alexthuth to user list
# ✅ Added work-account to user list
# 📋 Available users:
#   🟢 1. alexthuth (current)
#   ⚪ 2. work-account

# Assign user to project (much easier!)
ghs assign 2
# 💡 Using user #2: work-account
# ✅ Assigned work-account as default account for my-project

# See smart dashboard with current status and quick actions
ghs
# 🎯 GitHub Project Switcher
# 
# 📍 Current project: my-project
# 🔑 Current user: alexthuth (#1)
# ⚠️  Project should use: work-account (#2)
#
# 📋 Available users:
#   🟢 1. alexthuth (current)
#   ⚪ 2. work-account
#
# ⚡ Quick actions:
#   ghs switch 1    # Switch to alexthuth
#   ghs switch 2    # Switch to work-account
#   ghs assign 1    # Assign alexthuth to project
#   ghs assign 2    # Assign work-account to project

# Quick switch to any user by number
ghs switch 1
# ✅ Switched to alexthuth (#1)

# Check current status (shows user numbers!)
ghs status
# 📍 Current project: my-project
# 🔑 Current GitHub user: alexthuth (#1)
# ⚠️  This project should use: work-account (#2)

# See all users with numbers
ghs users
# 📋 Available users:
#   🟢 1. alexthuth (current)
#   ⚪ 2. work-account

# List all configured projects (shows user numbers!)
ghs list
# 📋 Configured project accounts:
#   🟢 my-project → work-account (#2) (current project)

# Get help
ghs help
```

### 🔧 Alternative: Direct Script Use

You can also run the script directly without installing:

```bash
# Assign account to project
./gh-switcher.sh assign work-username

# Switch to project account (automatic)
./gh-switcher.sh

# Check current status  
./gh-switcher.sh status

# List all configured projects
./gh-switcher.sh list
```

## Security Features

- **Input validation**: Username format validation prevents command injection
- **Atomic file operations**: Configuration updates are atomic to prevent corruption
- **Minimal permissions**: Only requires read/write to `~/.gh-project-accounts`
- **Delegates to official GitHub CLI**: No custom authentication logic

## Configuration File

Project accounts are stored in `~/.gh-project-accounts` with the format:
```
project-name=github-username
```

## Key Benefits

### 🎯 **Smart Dashboard & Numbered Users**
- **Discoverable**: Run `ghs` to see current status and all available actions
- **Contextual**: Shows exactly what you need to know: current user, project preference, and quick commands
- **Add once, use everywhere**: `ghs add-user alexthuth` → now you can use `#1` everywhere  
- **No more username typos**: `ghs assign 2` instead of `ghs assign my-complex-username`
- **Visual user list**: See all your accounts numbered and know which is currently active
- **Super fast switching**: `ghs switch 1` switches immediately

### 🔒 **Security & Reliability** 
- **Simple**: ~120 lines vs 270+ lines of complex alternatives
- **Secure**: Input validation, atomic operations, no shell injection risks
- **Reliable**: Delegates to official `gh` CLI for all authentication
- **Maintainable**: Easy to understand, modify, and audit
- **Focused**: Solves the core problems without unnecessary complexity

## Prerequisites

- [GitHub CLI](https://cli.github.com/) must be installed
- Your GitHub accounts must be authenticated with `gh auth login`

## Troubleshooting

**"Failed to switch to username"**: The account may not be authenticated. Run `gh auth login` to add the account.

**"No account configured"**: Run `ghs assign <username>` in your project directory to configure it.

**"GitHub CLI not found"**: Install the GitHub CLI from https://cli.github.com/ 