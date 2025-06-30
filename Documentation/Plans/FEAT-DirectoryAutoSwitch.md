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

- ✅ `link_directory()` - Create directory-profile link
- ✅ `unlink_directory()` - Remove directory-profile link  
- ✅ `find_directory_link()` - Find applicable link for current directory (with longest path matching)
- ✅ `check_directory_link()` - Check directory and handle auto-switching
- ✅ `prompt_auto_switch()` - Handle user interaction
- ✅ `detect_repository_suggestion()` - Smart suggestions based on remote
- ✅ `install_cd_hook()` - Auto-install shell integration
- ✅ `list_directory_links()` - Display all configured directory links
- ✅ `update_directory_link_mode()` - Update auto-switch mode for directories
- ✅ `switch_to_user()` - Internal function for switching users

### CLI Commands Implemented

- ✅ `ghs link <user> [directory] [mode]` - Link directory to profile
- ✅ `ghs unlink [directory]` - Remove directory link
- ✅ `ghs links` - List all directory links
- ✅ `ghs check-directory [--silent]` - Check current directory
- ✅ `ghs install-cd-hook [shell]` - Install shell integration

### Dashboard Integration

- ✅ Show directory link status in main dashboard
- ✅ Smart suggestions for Git repositories
- ✅ Visual indicators for matching/mismatching profiles

## Testing Plan

1. ✅ Test basic directory linking and unlinking
2. ✅ Test wildcard matching (implemented via longest path matching)
3. ✅ Test inheritance and overrides (most specific path wins)
4. ✅ Test auto-switch behaviors (always/never/ask)
5. ✅ Test smart detection from git remotes  
6. ✅ Test shell integration installation
7. ✅ Test dashboard integration

## Status

Completed

## Notes

- Keep performance in mind - cache directory checks where possible
- Most specific directory match wins (longest path)
- Provide clear shell installation instructions
- Consider simple .ghswitcher file support in future versions

## Implementation Notes

### Key Implementation Decisions

1. **Data Storage Format**: Used `~/.gh-directory-links` with format `path:username:auto_switch_mode`
   - Simple colon-separated format for easy parsing
   - Atomic file updates using temporary files
   - Most specific path matching (longest path wins)

2. **Auto-Switch Modes**: 
   - `always` - Switch immediately without prompting
   - `ask` - Show interactive prompt (default)
   - `never` - Don't prompt or switch

3. **Path Matching Strategy**:
   - Exact directory matches take priority
   - Subdirectory inheritance (parent directory links apply to children)
   - Wildcard support (e.g., `/home/user/work/*` matches all subdirectories)
   - Longest matching path wins (most specific)

4. **Smart Repository Detection**:
   - Analyzes `git remote -v` output for GitHub URLs
   - Extracts organization/username from GitHub URLs
   - Suggests matching configured users
   - Optional auto-linking with user confirmation

5. **Shell Integration**:
   - Hook function `ghs check-directory --silent` on `cd`
   - Auto-detects shell (bash, zsh, fish)
   - Graceful handling of missing directories or permissions

6. **User Experience**:
   - Silent mode for shell hooks (no output unless action needed)
   - Interactive prompts with clear options
   - Dashboard integration shows directory link status
   - Visual indicators for matching/mismatching profiles

### Performance Considerations

- Directory matching uses simple file reading (no complex caching needed)
- Git operations only run when in git repositories
- Silent mode prevents output spam during normal navigation
- Atomic file operations prevent corruption

### Error Handling

- Graceful handling of missing configuration files
- Path normalization using `realpath` where available
- Fallback to input path if `realpath` fails
- User validation before creating links
- Shell detection with fallback error messages

### Security Considerations

- User input validation (regex patterns for usernames)
- Path sanitization in grep operations
- Atomic file operations to prevent race conditions
- No execution of arbitrary commands from configuration files
