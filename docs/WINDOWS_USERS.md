# gh-switcher for Windows Users

gh-switcher is a bash script and does not run natively in PowerShell.

## Git Bash Support Status

✅ **Git Bash is tested in CI** - Core functionality works on Windows via Git Bash.

Known limitations on Windows:
- SSH key permissions cannot be strictly enforced (NTFS limitation)
- Performance is ~2x slower than Linux/macOS
- Some tests are skipped on Windows

## Recommended Options for Windows

### Option 1: WSL (Windows Subsystem for Linux) - Recommended
1. Install WSL: `wsl --install` (in PowerShell as admin)
2. Install gh-switcher in your WSL environment:
   ```bash
   curl -o gh-switcher.sh https://raw.githubusercontent.com/seconds-0/gh-switcher/main/gh-switcher.sh
   chmod +x gh-switcher.sh
   ./gh-switcher.sh install
   ```

### Option 2: Git Bash
1. Git Bash comes with Git for Windows
2. Run gh-switcher commands in Git Bash terminal
3. Follow standard installation instructions

### Option 3: Cygwin
1. Install Cygwin with bash package
2. Use gh-switcher within Cygwin environment

## Why PowerShell is Not Supported

gh-switcher uses bash-specific features that would require a complete rewrite for PowerShell:
- Bash functions and sourcing
- POSIX-style conditionals
- Shell parameter expansions
- Unix-style path handling

## VS Code on Windows

If using VS Code on Windows:
- The integrated terminal can use Git Bash or WSL
- Configure VS Code to use bash: `"terminal.integrated.defaultProfile.windows": "Git Bash"`

## Future PowerShell Support

There are no current plans to port gh-switcher to PowerShell. The recommended approach is to use one of the bash environments above, which provide full gh-switcher functionality on Windows.