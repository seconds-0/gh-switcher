# Changelog

All notable changes to gh-switcher will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-07-21

### Added
- Initial npm package release
- Core account switching functionality (`ghs switch`)
- SSH key management and validation
- Git hooks for commit protection (`ghs guard`)
- Project-specific user assignment (`ghs assign`)
- Multi-platform support (macOS, Linux, WSL)

### Security
- Secure storage of GitHub tokens
- SSH key permission validation (600)
- Pre-commit validation hooks

### Known Issues
- Windows support requires Git Bash or WSL
- Fish shell users may need to use bash wrapper

### Fixed Issues
- ✅ Fixed: `ghs remove 1` crashes terminal in zsh/vscode (whitespace in arithmetic comparisons)

[0.1.0]: https://github.com/seconds-0/gh-switcher/releases/tag/v0.1.0