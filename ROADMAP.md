# gh-switcher (ghs) Roadmap

## Mission
Lightning-fast GitHub account switcher for developers with multiple identities. Switch contexts, manage SSH keys, and prevent wrong-account commits - all in <100ms.

## Core Principles
- **Speed First**: Every command must execute in <100ms
- **Offline First**: No network dependencies for core operations
- **CLI First**: Scriptable, automatable, no interactive UIs
- **Simple Over Complex**: Avoid over-engineering

## Completed Features ✅

### Phase 1 Complete
- [x] **Core Switching** - `ghs switch <user>` with instant context change
- [x] **User Management** - Add, remove, list users
- [x] **Profile Management** - View and edit user profiles with `show`/`edit` commands
- [x] **Guard Hooks** - Pre-commit validation to prevent wrong-account commits
- [x] **Basic Directory Assignment** - Link directories to profiles with `assign`
- [x] **Enhanced Error States** - Verbose, actionable error messages with fix commands

## In Progress 🚧

### NPM Package Distribution
Package gh-switcher for easy installation via npm.

## High Priority Features 🔥

### Complete SSH Testing
Verify SSH keys actually authenticate with GitHub:
- [ ] Test authentication during `add` command
- [ ] Test authentication during `switch` command
- [ ] Clear success/failure messages
- [ ] Prevent failed git operations before they happen

### Multi-Host Support
Support different GitHub instances (enterprise vs public):
- [ ] Add --host parameter to commands
- [ ] Store host per profile
- [ ] Switch between github.com and enterprise instances
- [ ] Maintain separate auth per host

## Medium Priority Features 📋

### Override Git History
Fix commits made with wrong profile (from GitSwitch-CLI):
```bash
ghs override old@email.com "New Name" new@email.com
# Rewrites commit history in current repo
# ⚠️  This changes git history - use with caution
```

### Global Profile Registry
See all profiles across all projects:
```bash
ghs list --global
# alice-work (used in: ~/projects/work, ~/projects/client)
# bob-personal (used in: ~/projects/hobby)
# charlie-oss (used in: ~/projects/contrib)
```

### Directory Auto-Switch Enhancement
Complete the auto-switching experience:
- [ ] Shell integration (cd hooks)
- [ ] Parent directory inheritance
- [ ] Opt-out safe mode

## Low Priority Features 💭

### Profile Statistics
Show commit activity per profile:
```bash
ghs stats alice
# Commits: 234
# Active repos: 5
# Last used: 2 hours ago
```

### Core Enhancements

#### Smart Repository Detection
Prevent using wrong profile based on remote URL patterns:
```bash
ghs check
# Warning: This looks like a work project
# Recommended: work-account
```

#### Local Profile Backup
Simple backup without cloud dependencies:
```bash
ghs backup
# Saved to ~/.gh-switcher-backup-2024-01-15.tar.gz
```


### Quality of Life Improvements

#### Quick Switching
Numbered shortcuts for frequent users:
```bash
ghs 1  # Switch to first user
ghs 2  # Switch to second user
```

#### Profile Aliases
Memorable shortcuts:
```bash
ghs alias work alice-work
ghs switch @work  # Instead of full username
```

#### Recent Profiles
Quick access to recently used:
```bash
ghs recent
# 1. alice-work (current)
# 2. bob-personal (2 hours ago)
# 3. alice-oss (yesterday)
```

#### Minimal Status for PS1
Shell prompt integration:
```bash
export PS1='$(ghs prompt) $ '
# Shows: [alice-work] $ 
```


## Out of Scope ❌

These features have been considered but rejected to maintain focus:

- **Team Sharing/Import/Export** - Adds complexity without core value
- **Profile Templates** - Over-engineers simple profile creation  
- **Cloud Sync** - Violates offline-first principle
- **Interactive TUI** - Goes against CLI-first philosophy
- **Workflow Wizards** - Over-complicates simple commands
- **Advanced Git Config Management** - Scope creep into git territory
- **QR Codes/Share URLs** - Unnecessary complexity

## Success Metrics

- All commands execute in <100ms
- Zero network requests for core operations
- <1000 lines of code (maintainability)
- 100% test coverage for critical paths
- Works perfectly offline

## Contributing

Focus areas for contributions:
1. Performance improvements (maintain <100ms)
2. Better error messages and recovery suggestions
3. Shell integration improvements
4. Test coverage for edge cases

Remember: User delight through speed and simplicity, not feature count.