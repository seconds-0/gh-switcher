# ✨ Enhanced Profiles, UX Polishing & Documentation Overhaul

## Overview

This pull request delivers the **v3 Enhanced Profile implementation** alongside a suite of UX refinements and documentation updates. The goal is to solidify gh-switcher's core ergonomics while keeping true to the CLI-first philosophy.

## Highlights

1. **Enhanced Profile v3 (plain-text)**  
   • Migrated profile store to `username:name:email[:gpg][:auto_sign]` format.  
   • Added strict validation (`validate_profile_field`) and structured parser `parse_profile_line_v3`.  
   • `create_user_profile`, `apply_user_profile`, and helpers now fully understand v3.
2. **New & Improved Commands**  
   • `ghs update <user> <field> "<value>"` – granular profile edits.  
   • `ghs validate [user]` – health-check and linter for profiles.  
   • `ghs profiles --verbose` – inspect stored data.  
   • Dashboard auto-creates profiles on first switch, reducing onboarding friction.
3. **Smarter Dashboard & Status Flow**  
   • Real-time git-config vs profile mismatch detection.  
   • Project-account guidance with quick-action command suggestions.  
   • First-time setup wizard detects unauthenticated/empty state.
4. **UX Polish**  
   • Replaced garbled header glyph with 🎯 for title banners.  
   • Consistent emoji usage with actionable hints (✅, ⚠️, ❌).  
   • Return-codes cleaned for better scriptability (non-error paths stay zero).
5. **README Revamp**  
   • Comprehensive command matrix including `users`, `remove-user`, `validate`, `help`.  
   • Added uninstall instructions, profile format, examples, and config file reference.  
   • Synced feature list with current CLI.
6. **New Planning Doc**  
   • `Documentation/Plans/TWEAK-UXAuditFixes.md` tracks audit fixes, checklist, and status (Completed).

## File-Level Breakdown

| File                                        | Notes                                                                                    |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `gh-switcher.sh`                            | 1,900-line refactor: v3 profile helpers, new commands, UX copy updates, emoji header fix |
| `README.md`                                 | Command coverage expansion, new sections, Help / uninstall docs                          |
| `Documentation/Plans/TWEAK-UXAuditFixes.md` | Workplan added & completed                                                               |
| `CHANGELOG.md`                              | _Pending next release tagging_                                                           |

## Testing & Verification

- Manual smoke test across macOS bash & zsh.
- Verified `ghs help`, `ghs add-user`, `ghs switch`, `ghs assign`, dashboard, and validation outputs.
- Ensured non-interactive flows return proper exit codes for CI scripting.

## Backwards Compatibility

- Legacy v1/v2 profiles remain readable (`decode_profile_value` shim retained).
- No breaking changes to existing commands; only additive or cosmetic.

## Follow-ups

- Stabilise numeric user IDs (persist mapping file).
- Introduce a `--dry-run` flag for git-config application.
- Add automated bats test-suite (see `Documentation/Plans/TEST-ComprehensiveTestPlan.md`).

---

> _Thank you for reviewing!_
