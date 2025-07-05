# 🎯 GitHub Switcher Roadmap

## Current Status: v1.1.0 – Enhanced Profiles & UX Polish Released

The tool works perfectly for personal and team use with the current simple implementation. This roadmap outlines potential future enhancements based on user feedback and adoption.

## Phase 1: Polish & Stability (v1.x)

### Completed in 1.1.0

- [x] Enhanced Profile v3 (plain-text, validation)
- [x] Dashboard improvements & git-config drift detection
- [x] README and help text overhaul
- [x] Emoji header & UX copy polish

### Remaining / New Candidates

- [ ] User aliasing system (`ghs alias 1 work`)
- [ ] Backup/restore functionality (`ghs backup`, `ghs restore`)
- [ ] Project template patterns (`ghs set-pattern "work-*" work-account`)
- [ ] Shell prompt integration function
- [ ] Dry-run mode (`--dry-run`)

### Quality Improvements

- [ ] Shell completion scripts (bash, zsh, fish)
- [ ] Comprehensive automated test suite (bats)
- [ ] CI/CD pipeline
- [ ] Installation scripts

## Phase 2: Library Distribution (v2.0.0) - _If Widely Adopted_

**Architecture Changes**

- [ ] XDG-compliant configuration directories
- [ ] Namespace isolation for multiple tools
- [ ] API separation (core logic vs. UI)
- [ ] Configurable project detection
- [ ] Enhanced error handling with return codes

**Distribution**

- [ ] npm package (`npm install -g gh-switcher`)
- [ ] Homebrew formula (`brew install gh-switcher`)
- [ ] Shell completion integration
- [ ] Migration system for legacy configs

**API Structure**

```bash
# Core API functions (return data, no direct output)
gh_switcher_init(namespace, config_dir)
gh_switcher_add_user(username) -> return_code
gh_switcher_get_users() -> structured_data
gh_switcher_set_project(project, user) -> return_code
gh_switcher_switch_user(username) -> return_code

# UI functions (customizable presentation)
gh_switcher_show_dashboard()
gh_switcher_format_user_list()
```

## Guiding Principles

**Start Small, Grow Smart**: Only implement features when there's proven demand
**Preserve Simplicity**: Maintain the core UX that makes this tool special
**Backward Compatibility**: Never break existing workflows
**User-Driven**: Let real usage patterns drive development priorities

## Success Metrics

- **Phase 1 Trigger**: 100+ GitHub stars or 10+ user requests
- **Phase 2 Trigger**: 500+ GitHub stars or clear community adoption
- **Always**: Tool remains useful for original single-user case

---

_This roadmap is intentionally conservative. The current implementation is excellent for personal use. Future development depends entirely on real user adoption and feedback._
