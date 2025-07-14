# Task ID: FEAT-GuardHooks

## Problem Statement

Developers can inadvertently commit or push code using the wrong GitHub account when working on multiple projects. Although `gh-switcher` currently surfaces mismatches in its dashboard, it does not PREVENT mistakes. We need a guard-rail that blocks (or at least explicitly warns) when commits or pushes occur under a mis-aligned account.

## Proposed Solution

Implement an **opt-in Guard Hooks system** powered by Git hooks (`pre-commit` & `pre-push`). The hooks will:

1. Determine the project's expected user via `~/.gh-project-accounts`.
2. Verify:
   - `gh auth status` user matches expected user.
   - `git config user.name` / `user.email` match the saved profile for that user.
3. Fail with ❌ and helpful instructions if mismatched; warn (⚠️) when no account is assigned; bypass when `GHS_GUARD_SKIP=1` or `--no-verify` is used.
4. Provide CLI helpers: `ghs guard install | uninstall | status | global-install`.

## Automated Test Plan

- Unit tests for mismatch detection logic (mock `git` and `gh` outputs).
- Integration tests using a temporary repo, setting up various mismatch scenarios.
- Timing test to assert guard overhead < 100 ms.

## Components Involved

- `gh-switcher.sh` (new functions `guard_install`, `guard_uninstall`, etc.)
- New script `scripts/guard-hook.sh` stored under `scripts/` (single source for hooks).
- Documentation updates (README, ROADMAP).

## Dependencies

- Existing helper functions: `detect_git_config`, `get_current_github_user`, `get_user_profile`.
- Git & GitHub CLI already required.

## Implementation Checklist

- [x] Add `scripts/guard-hook.sh` (core detection logic)
- [x] Add `ghs guard <subcommand>` parsing in `gh-switcher.sh`
- [x] Implement per-repo `install`/`uninstall` (write to `.git/hooks`)
- [ ] Implement `global-install` (set `core.hooksPath` to central dir) - Future enhancement
- [x] Implement `status` command (detect installed hooks)
- [x] Update CLAUDE.md with usage & bypass instructions
- [x] Implement `test` command for dry-run validation
- [ ] Write automated tests (bats) under `tests/guard_hooks/` - Future enhancement
- [ ] Update change-log & roadmap - Future enhancement

## Verification Steps

1. ✅ Create repo with assigned account → commit/push succeeds.
2. ✅ Switch to wrong account → commit fails with ❌.
3. ✅ Run with `GHS_SKIP_HOOK=1` → commit succeeds.
4. ⏳ CI pipeline (`CI=true`) logs warning but does not fail - To be tested.

## Implementation Notes

### Completed Features
- **Guard Commands**: `ghs guard install|uninstall|status|test`
- **Automatic Validation**: Pre-commit hook validates GitHub account vs project assignment
- **Smart Detection**: Finds guard-hook.sh via multiple path strategies
- **Backup Protection**: Automatically backs up existing pre-commit hooks
- **User-Friendly**: Clear error messages and guidance for fixes
- **Bypass Support**: `GHS_SKIP_HOOK=1` environment variable override

### Changes from Original Plan
- Used `GHS_SKIP_HOOK=1` instead of `GHS_GUARD_SKIP=1` for consistency
- Added `test` subcommand for dry-run validation
- Focused on pre-commit hooks only (pre-push hooks deferred)
- Global installation deferred to future enhancement

## Status

Implemented (Core Features Complete)

## Future Enhancements
- Global hooks installation via `core.hooksPath`
- Pre-push hook validation
- Comprehensive test suite
- Remote URL ownership validation

## Notes

Initial design agreed in chat on <date>. Will revisit performance numbers after prototype.
