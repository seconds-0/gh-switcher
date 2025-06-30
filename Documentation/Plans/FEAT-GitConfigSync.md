# FEAT-GitConfigSync - Auto-detect and Configure Git User Settings

## Task ID

FEAT-GitConfigSync

## Problem Statement

When switching between GitHub accounts using `ghs`, the local git configuration (user.name and user.email) often doesn't match the active GitHub account. This creates a mismatch where commits are authored by one identity while PRs are created by another, causing unintended co-authorship attribution.

## Proposed Solution

Enhance the `ghs switch` command to:

1. **Detect git config mismatch** - Compare current git config with target GitHub account
2. **Prompt for action** - Offer choices when mismatch is detected
3. **Apply configuration** - Update git config to match target account
4. **Remember preferences** - Store user choices for future switches
5. **Provide revert options** - Allow easy restoration of previous config

### Implementation Approach

- Extend the existing `switch` command with git config detection
- Add new helper functions for git config management
- Create a preferences system to remember user choices
- Use GitHub's noreply email format for privacy
- Support both global and local git configuration

## Automated Test Plan

- **Unit tests** for git config detection functions
- **Integration tests** for the complete switch workflow
- **User preference tests** for remembering choices
- **Edge case tests** for missing git config, uninitialized repos, etc.
- **Manual testing** with real GitHub accounts and git repositories

## Components Involved

- **Main `ghs()` function** - Extend `switch` command logic
- **Git config detection** - New helper functions
- **User preference storage** - Extend existing config file system
- **GitHub API integration** - Fetch user details for email detection
- **Interactive prompting** - User choice interface

## Dependencies

- Existing GitHub CLI (`gh`) authentication
- Git command line tool availability
- Current user/project config system
- GitHub API access for user information

## Implementation Checklist

### Phase 1: Core Git Config Detection

- [x] Create `detect_git_config()` function to read current user.name/user.email
- [x] Create `get_github_user_details()` function to fetch target account info
- [x] Create `compare_git_github_config()` function to detect mismatches
- [x] Add git config detection to existing `switch` command
- [x] Test basic detection functionality

### Phase 2: User Interaction & Choice Handling

- [x] Create interactive prompt for mismatch resolution
- [x] Implement three choice options:
  - [x] Update git config to match GitHub account
  - [x] Keep current git config (no change)
  - [x] Configure custom name/email
- [x] Add support for global vs local git config selection
- [x] Test user interaction flow

### Phase 3: Git Config Application

- [x] Create `apply_git_config()` function to update user.name/user.email
- [x] Support both `git config --global` and `git config` (local)
- [x] Use GitHub noreply email format: `{username}@users.noreply.github.com`
- [ ] Store previous config for revert functionality
- [x] Test git config application

### Phase 4: Preference Storage & Memory

- [ ] Extend config file to store user preferences
- [ ] Add preference keys for account pairs (e.g., `account1->account2=auto_update`)
- [ ] Implement `remember this choice` functionality
- [ ] Add preference management commands (`ghs config-prefs`)
- [ ] Test preference storage and retrieval

### Phase 5: Advanced Features & Polish

- [ ] Add `--skip-git-config` flag to bypass git config changes
- [ ] Add revert functionality to restore previous git config
- [ ] Improve error handling for git command failures
- [ ] Add configuration validation (valid email format, etc.)
- [ ] Update help text and documentation

## Verification Steps

1. **Mismatch Detection**: Verify tool correctly identifies when git config doesn't match GitHub account
2. **Choice Presentation**: Confirm all three options are presented clearly
3. **Config Application**: Test that git config is updated correctly (both global and local)
4. **Preference Memory**: Verify choices are remembered for future switches
5. **Edge Cases**: Test with no git config, uninitialized repos, invalid accounts
6. **Real World**: Test with multiple actual GitHub accounts and repositories

## Decision Authority

**Independent Decisions**:

- Implementation details of helper functions
- Error message formatting and user prompts
- Technical approach for config storage
- Function naming and code organization

**User Input Required**:

- Default behavior when no preference is stored
- Whether to make git config changes opt-in or opt-out
- UI/UX for preference management commands

## Questions/Uncertainties

### Blocking Questions

1. **Default behavior**: When no preference is stored, should the tool default to prompting every time, or have a default action?
2. **Privacy concerns**: Should we use GitHub's noreply email by default, or try to fetch the user's actual email?

### Non-blocking Questions (Working Assumptions)

1. **Email format**: Will use `{username}@users.noreply.github.com` format for privacy
2. **Config scope**: Will ask user to choose between global and local, defaulting to local
3. **Preference storage**: Will extend existing config file format rather than create new files

## Acceptable Tradeoffs

- **Performance**: Acceptable to add git config check overhead to switch command
- **Complexity**: Acceptable to add interactive prompts in exchange for better UX
- **Dependencies**: Acceptable to require git CLI in addition to GitHub CLI

## Status

REDESIGNED & COMPLETED - Smart Profile-Based System

## Notes

This feature addresses the core UX issue where users switch GitHub accounts but forget to update git config, leading to authorship confusion.

**MAJOR REDESIGN:** After initial implementation, the approach was completely redesigned based on user feedback to be much smarter and less intrusive.

### Final Implementation: Profile-Based System

**🎯 New Approach:**
Instead of prompting users every time, the system now creates **user profiles** that link GitHub accounts to their preferred git configurations.

**✅ How It Works:**

1. **First-time setup**: Auto-detects current GitHub user and creates profile from current git config
2. **Adding users**: Auto-creates profiles from current git config when new users are added
3. **Switching**: Automatically applies the stored profile for each user (no prompts!)
4. **Smart detection**: Only intervenes when there are real conflicts

**✅ Completed Features:**

- **User Profile System** (`~/.gh-user-profiles`) - Links GitHub usernames to git config preferences
- **First-time Setup** - Auto-profiles current user and assigns to current project
- **Auto-Profile Creation** - New users get profiles from current git config
- **Seamless Switching** - Profiles applied automatically during switch
- **Dashboard Integration** - Shows git config status (✅ matches / ⚠️ mismatch)
- **Profile Management** - `ghs profiles` and `ghs update-profile` commands
- **Smart Integration** - Works WITH existing project assignment system

**🎯 User Experience:**

- **Zero prompts** for normal workflow (switch just works)
- **Automatic learning** from user's current setup
- **Visual feedback** in dashboard about config status
- **Manual control** when needed via profile commands

**🔧 Commands Added:**

- `ghs profiles` - View all user profiles
- `ghs update-profile <user>` - Manually update a profile
- Enhanced dashboard with git config status display
- First-time setup runs automatically

**📊 Benefits Over Original Design:**

- **No prompt fatigue** - Switching is instant again
- **Learns from user behavior** - Captures preferences automatically
- **Respects existing assignments** - Works with project-specific user assignments
- **Maintains simplicity** - Complex logic hidden from user
- **Performance friendly** - No API calls during normal switching

This completely solves the original UX issue without introducing new friction. The system is now intelligent enough to "just work" while still allowing manual control when needed.
