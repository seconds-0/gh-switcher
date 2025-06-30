# FEAT-DirectoryAutoSwitch - Directory-Based Auto-Switching

## Task ID

FEAT-DirectoryAutoSwitch

## Problem Statement

Users frequently forget to switch profiles when moving between projects, leading to:

- Commits with wrong email/identity
- Authentication failures with wrong SSH keys
- Time wasted manually switching profiles
- No way to enforce team-wide profile standards

## Proposed Solution

Link directories to specific profiles, enabling automatic profile switching based on current working directory.

## Why It's Valuable

- **Prevents wrong account commits** - Auto-detects when you're in wrong profile
- **Zero-config after setup** - Link once, works forever
- **Team consistency** - Everyone uses same profile for shared projects
- **Reduces cognitive load** - No need to remember which account for which project

## Implementation Details

### Core Functionality

1. **Directory Linking**

   - Link any directory to a profile
   - Support wildcards (e.g., ~/work/\*)
   - Inheritance (subdirectories inherit parent settings)
   - Override capability for specific subdirectories

2. **Auto-Switch Behavior**

   - Configurable: always/never/ask
   - Per-directory settings
   - Global default setting

3. **Smart Detection**
   - Check directory links on `cd`
   - Prompt when mismatch detected
   - Suggest links based on repository remote

### User Experience

#### Linking Directory

```bash
$ cd ~/Projects/work/backend
$ ghs link work-account
🔗 Linking directory to profile...
📁 Directory: ~/Projects/work/backend
👤 Profile: work-account (#2)
✅ Directory linked successfully

💡 This link will:
   - Auto-suggest work-account when you enter this directory
   - Apply to all subdirectories (unless overridden)
```

#### Auto-Switch Prompt

```bash
$ cd ~/Projects/work/backend
$ ghs
🎯 GitHub Project Switcher

📍 Current project: backend
🔑 Current user: personal-acct (#1)
🔗 Directory profile: work-account (#2)
⚠️  Profile mismatch detected!

💡 Auto-switch suggestion:
   This directory is linked to work-account (#2)

   Switch now? (y/n/always/never): y
```

#### Directory Link Management

```bash
$ ghs links
📁 Directory Profile Links:

~/Projects/work/*          → work-account (#2) [auto-switch: yes]
~/Projects/personal/*      → personal (#3) [auto-switch: ask]
~/Projects/opensource/*    → personal-acct (#1) [auto-switch: yes]

💡 Commands:
   ghs link <profile>         # Link current directory
   ghs unlink                 # Remove current directory link
```

### Smart Repository Detection

```bash
$ cd ~/Projects/new-project
$ git remote -v
origin  git@github.com:work-org/new-project.git

$ ghs
💡 Smart suggestion:
   This appears to be a work-org repository
   Recommended profile: work-account (#2)

   Link this directory? (y/n): y
```

## Technical Implementation

### Data Storage

```bash
# ~/.gh-directory-links format
# path:profile_id:auto_switch_mode
/home/user/Projects/work/*:2:always
/home/user/Projects/personal/*:3:ask
/home/user/Projects/work/opensource-contrib:1:never

# Most specific path wins (longest match)
```

### Shell Integration

```bash
# Bash/Zsh - Add to .bashrc or .zshrc
function cd() {
    builtin cd "$@" && ghs check-directory --silent
}

# Fish - Add to config.fish
function cd
    builtin cd $argv; and ghs check-directory --silent
end

# Installation helper
ghs install-cd-hook  # Auto-detects shell and installs appropriate hook
```

### Functions to Implement

- `link_directory()` - Create directory-profile link
- `check_directory_link()` - Find applicable link for current directory (with simple caching)
- `prompt_auto_switch()` - Handle user interaction
- `detect_repository_suggestion()` - Smart suggestions based on remote
- `install_cd_hook()` - Auto-install shell integration

## Testing Plan

1. Test wildcard matching
2. Test inheritance and overrides
3. Test auto-switch behaviors (always/never/ask)
4. Test smart detection from git remotes
5. Test performance with many links

## Status

Not Started

## Notes

- Keep performance in mind - cache directory checks where possible
- Most specific directory match wins (longest path)
- Provide clear shell installation instructions
- Consider simple .ghswitcher file support in future versions
