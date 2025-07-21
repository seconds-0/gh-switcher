# NPM Package Implementation Plan for gh-switcher

## Overview
This document outlines the complete implementation plan for publishing gh-switcher to the npm registry, making it available for installation via `npm install -g gh-switcher`.

## Timeline Estimate
- **Total Duration**: 4-6 hours of focused work
- **Recommended**: Split across 2 days to allow for testing and issue resolution

## Implementation Phases

### Phase 0: Prerequisites Check (15 minutes)

#### 0.1 System Requirements Validation
**Priority**: CRITICAL  
**Time**: 15 minutes

**Create and run prerequisites check script**:
```bash
cat > check-prerequisites.sh << 'EOF'
#!/bin/bash
set -e

echo "🔍 Checking NPM publishing prerequisites..."

# Function to check command exists
check_command() {
    local cmd=$1
    local min_version=$2
    local install_url=$3
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd is required but not installed"
        echo "   Install from: $install_url"
        return 1
    else
        echo "✅ $cmd found: $(command -v $cmd)"
        if [[ -n "$min_version" ]]; then
            local version=$($cmd --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            echo "   Version: $version (minimum: $min_version)"
        fi
    fi
}

# Check Node.js
check_command node "14.0.0" "https://nodejs.org/"

# Check npm
check_command npm "6.0.0" "Comes with Node.js"

# Check npx
check_command npx "" "Comes with npm 5.2+"

# Check git
check_command git "" "https://git-scm.com/"

# Check for json package (used in many commands)
if ! npx json --version >/dev/null 2>&1; then
    echo "⚠️  json package not found globally, installing..."
    npm install -g json
fi

# Check Docker (optional but recommended)
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker found (optional, for cross-platform testing)"
else
    echo "⚠️  Docker not found (optional, needed for Linux testing)"
fi

# Check shell
echo "📍 Current shell: $SHELL"

# Check for potential conflicts
if type ghs >/dev/null 2>&1; then
    echo "⚠️  Warning: 'ghs' command already exists at: $(which ghs)"
    echo "   This may conflict with gh-switcher installation"
fi

echo ""
echo "✅ Prerequisites check complete!"
EOF

chmod +x check-prerequisites.sh
./check-prerequisites.sh
```

**Critical checks**:
- Node.js >= 14.0.0 (for modern npm features)
- npm >= 6.0.0 (for security features)
- npx available (comes with npm 5.2+)
- git installed (for repository management)
- No existing `ghs` command conflicts

**Checkpoint**: ✓ All prerequisites installed and versions verified

### Phase 1: Preparation & Verification (30 minutes)

#### 1.1 Package Name Availability Check
**Priority**: HIGH  
**Time**: 10 minutes

**Tasks**:
1. Check primary name availability:
   ```bash
   npm view gh-switcher
   ```
   **Expected output**: `npm ERR! code E404` (means available)
   **If taken**: You'll see package details instead
   
   **Critical**: Save the exact output for decision making

2. Check alternative names systematically:
   ```bash
   # Run all at once to save time (works on all platforms)
   for name in gh-switcher ghs ghs-cli gh-account-switcher "@seconds-0/gh-switcher"; do
       if npm view "$name" 2>&1 | grep -q "E404"; then
           echo "✅ $name available"
       else
           echo "❌ $name taken"
       fi
   done
   ```

3. **Decision Matrix**:
   | Name | Available | Pros | Cons | Score |
   |------|-----------|------|------|-------|
   | gh-switcher | ? | Descriptive, clear purpose | Longer to type | ? |
   | ghs | ? | Short, matches command | May be taken, less discoverable | ? |
   | ghs-cli | ? | Clear it's a CLI tool | Redundant with command | ? |
   | @seconds-0/gh-switcher | ? | Namespace control | Less discoverable | ? |

4. **Fallback Strategy** (if all names taken):
   - Consider variations: `github-switcher`, `gh-switch`, `ghswitcher`
   - Use scoped package with your npm username
   - Add suffix: `gh-switcher-cli`, `gh-switcher-tool`

**Decision Point**: Document chosen package name: ________________

**Critical Agent Note**: The package name MUST match exactly in:
- package.json "name" field
- npm publish command
- All documentation references
- README badges URLs

#### 1.2 NPM Account Setup
**Priority**: HIGH  
**Time**: 20 minutes

**Pre-check**:
```bash
# Check if already logged in
npm whoami
# If returns username, skip to step 5
```

**Tasks**:
1. **Create npm account** (skip if exists):
   - Navigate to https://www.npmjs.com/signup
   - Username requirements: lowercase, no spaces, unique
   - Strong password required
   - Valid email for verification

2. **Enable 2FA** (MANDATORY for publishing):
   ```bash
   # After account creation, check 2FA status
   npm profile get two-factor
   ```
   - If not enabled: Settings → Password and 2FA → Enable 2FA
   - **Use authenticator app** (Google Authenticator, Authy, 1Password)
   - **CRITICAL: Save backup codes in password manager**
   - Write down backup codes location: ________________
   - Test 2FA works before proceeding

3. **Organization creation** (optional but recommended):
   - Only if username "seconds-0" matches GitHub
   - Allows scoped packages like @seconds-0/package-name
   - Future-proofs for multiple packages

4. **Local authentication**:
   ```bash
   # For 2FA-enabled accounts (most common)
   npm login --auth-type=web
   # This opens browser for secure login
   
   # Alternative if web auth fails
   npm login --auth-type=legacy
   # Username: [your-username]
   # Password: [hidden]
   # Email: [your-email]
   # OTP: [2FA code]
   ```

5. **Verify authentication** (without exposing token):
   ```bash
   npm whoami
   # Should return your username
   
   # Verify .npmrc exists (DO NOT cat this file)
   [[ -f ~/.npmrc ]] && echo "✅ npm credentials saved" || echo "❌ No credentials"
   ```

6. **Secure .npmrc**:
   ```bash
   # Ensure .npmrc is not in version control
   echo ".npmrc" >> .gitignore
   git add .gitignore
   git commit -m "chore: ensure .npmrc is ignored"
   ```

**Troubleshooting**:
- **"ENEEDAUTH" error**: Not logged in properly
- **"E401" error**: Authentication failed, re-login
- **OTP issues**: Wait for new code, don't reuse
- **2FA device lost**: Use backup codes from password manager

**Checkpoint**: ✓ `npm whoami` returns your username

### Phase 2: Package Configuration (45 minutes)

#### 2.0 Script Preparation
**Priority**: CRITICAL  
**Time**: 5 minutes

**Ensure script is executable and has shebang**:
```bash
# Check shebang
head -1 gh-switcher.sh | grep -q "^#!/bin/bash" || {
    echo "❌ Missing shebang! Adding..."
    # Create temp file with shebang
    echo '#!/bin/bash' > temp.sh
    cat gh-switcher.sh >> temp.sh
    mv temp.sh gh-switcher.sh
}

# Ensure executable
chmod +x gh-switcher.sh

# Verify
ls -la gh-switcher.sh
head -1 gh-switcher.sh

# Commit if changed
git add gh-switcher.sh
git diff --cached gh-switcher.sh && git commit -m "fix: ensure gh-switcher.sh has shebang and is executable"
```

#### 2.1 Update package.json with Publishing Metadata
**Priority**: HIGH  
**Time**: 25 minutes

**Pre-validation**:
```bash
# Check current package.json is valid JSON
npx json -f package.json -e 'this' > /dev/null && echo "✅ Valid JSON" || echo "❌ Invalid JSON"

# Backup current package.json
cp package.json package.json.backup
```

**Required Updates** (exact format matters):

1. **Add bin configuration**:
   ```json
   "bin": {
     "ghs": "./gh-switcher.sh"
   }
   ```
   **Critical**: The file path must be relative to package root
   **Verify**: File exists and is executable (we did this in 2.0)

2. **Add files whitelist** (controls package size):
   ```json
   "files": [
     "gh-switcher.sh",
     "LICENSE",
     "README.md"
   ]
   ```
   **Note**: package.json is always included automatically
   **Excludes**: test files, docs, .git, node_modules

3. **Add complete metadata** (REPLACE PLACEHOLDERS):
   ```json
   "name": "gh-switcher",
   "version": "0.1.0",
   "description": "Lightning-fast GitHub account switcher for developers with multiple identities",
   "keywords": [
     "github",
     "cli",
     "git",
     "account-switcher",
     "ssh",
     "developer-tools",
     "github-cli",
     "multi-account"
   ],
   "homepage": "https://github.com/seconds-0/gh-switcher#readme",
   "bugs": {
     "url": "https://github.com/seconds-0/gh-switcher/issues"
   },
   "repository": {
     "type": "git",
     "url": "git+https://github.com/seconds-0/gh-switcher.git"
   },
   "author": {
     "name": "REPLACE_WITH_YOUR_NAME",
     "email": "REPLACE_WITH_YOUR_EMAIL",
     "url": "https://github.com/REPLACE_WITH_YOUR_GITHUB"
   },
   "license": "MIT",
   "engines": {
     "node": ">=14.0.0"
   },
   "os": [
     "darwin",
     "linux",
     "!win32"
   ]
   ```

   **⚠️ CRITICAL**: Replace ALL placeholders:
   - REPLACE_WITH_YOUR_NAME
   - REPLACE_WITH_YOUR_EMAIL  
   - REPLACE_WITH_YOUR_GITHUB

4. **Create .npmignore** (backup to files field):
   ```bash
   cat > .npmignore << 'EOF'
# Test files
test/
*.test.sh
bats/

# Documentation
Documentation/
*.md
!README.md

# Development files
.github/
.gitignore
.npmignore
pre-publish-check.sh
check-prerequisites.sh

# OS files
.DS_Store
*.swp

# Logs
*.log
npm-debug.log*
EOF
   ```

5. **Validate changes**:
   ```bash
   # Verify no placeholders remain
   grep -E "REPLACE_WITH|Your Name|your\.email" package.json && echo "❌ Placeholders found!" || echo "✅ No placeholders"
   
   # Check for missing required fields
   for field in name version description author license; do
       npx json -f package.json $field >/dev/null || echo "❌ Missing: $field"
   done
   
   # Verify bin points to executable
   [[ -x "$(npx json -f package.json bin.ghs)" ]] && echo "✅ Bin file is executable" || echo "❌ Bin file not executable"
   ```

**Common Mistakes**:
- Wrong bin path (must start with ./)
- Missing executable permissions on script
- Invalid characters in keywords
- Malformed author field
- **Forgetting to replace placeholder text**

#### 2.2 Verify LICENSE file
**Priority**: MEDIUM  
**Time**: 15 minutes

**Validation sequence**:
```bash
# 1. Check file exists
[[ -f LICENSE ]] && echo "✅ LICENSE exists" || echo "❌ LICENSE missing"

# 2. Check not empty
[[ -s LICENSE ]] && echo "✅ LICENSE has content" || echo "❌ LICENSE empty"

# 3. Verify matches package.json
PKG_LICENSE=$(npx json -f package.json license)
grep -q "$PKG_LICENSE" LICENSE && echo "✅ License type matches" || echo "❌ License mismatch"

# 4. Check copyright year
grep -q "$(date +%Y)" LICENSE && echo "✅ Current year" || echo "⚠️  Update copyright year"

# 5. Check for placeholder text
grep -E "Your Name|\[Your Name\]" LICENSE && echo "❌ Placeholder in LICENSE" || echo "✅ No placeholders"
```

**If creating new LICENSE**:
```bash
# Get author name from package.json
AUTHOR_NAME=$(npx json -f package.json author.name)

# For MIT License
cat > LICENSE << EOF
MIT License

Copyright (c) $(date +%Y) $AUTHOR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

**Checkpoint**: ✓ LICENSE file valid and matches package.json

### Phase 3: Documentation Updates (45 minutes)

#### 3.1 Update README.md with npm Focus
**Priority**: HIGH  
**Time**: 30 minutes

**Backup first**:
```bash
cp README.md README.md.backup
echo "✅ README backed up to README.md.backup"
```

**Required Updates**:

1. **Add npm badges** (must be on line 3, after title and blank line):
   ```markdown
   # gh-switcher (ghs)
   
   [![npm version](https://img.shields.io/npm/v/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
   [![npm downloads](https://img.shields.io/npm/dm/gh-switcher)](https://www.npmjs.com/package/gh-switcher)
   [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
   ```
   **Note**: Replace "gh-switcher" with chosen package name
   **Note**: Badges will show 404 until package is published - this is normal

2. **Update Installation section** (npm must be first):
   ```markdown
   ## Installation
   
   ### Via npm (Recommended)
   ```bash
   npm install -g gh-switcher
   ```
   
   After installation, the `ghs` command will be available globally.
   
   ### Prerequisites
   Before installing gh-switcher, ensure you have:
   - **Node.js** (v14 or higher) - [Installation guide](https://nodejs.org/)
   - **Git** - [Installation guide](https://git-scm.com/downloads)
   - **GitHub CLI** (`gh`) - [Installation guide](https://cli.github.com/manual/installation)
   
   Verify prerequisites:
   ```bash
   node --version   # Should show v14.0.0 or higher
   git --version    # Should show git version
   gh --version     # Should show gh version
   ```
   
   ### Platform Support
   - ✅ **macOS**: Full support
   - ✅ **Linux**: Full support  
   - ⚠️  **Windows**: Requires Git Bash or WSL (not native CMD/PowerShell)
   
   ### Manual Installation
   [Move existing curl/wget instructions here - DO NOT DELETE]
   ```

3. **Add Troubleshooting section** (before Contributing):
   ```markdown
   ## Troubleshooting
   
   ### npm Installation Issues
   
   **Permission denied (EACCES) during global install**:
   ```bash
   # Option 1: Configure npm to use a different directory (recommended)
   mkdir ~/.npm-global
   npm config set prefix '~/.npm-global'
   echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc  # or ~/.bashrc
   source ~/.zshrc  # or source ~/.bashrc
   npm install -g gh-switcher
   ```
   
   **Command not found after installation**:
   ```bash
   # Check npm global bin location
   npm config get prefix
   # Add to PATH if needed
   export PATH="$(npm config get prefix)/bin:$PATH"
   ```
   
   **Existing command conflicts**:
   ```bash
   # Check if ghs already exists
   which ghs
   # If it exists, uninstall conflicting package first
   ```
   
   **Windows-specific issues**:
   - Must use Git Bash or WSL, not Command Prompt or PowerShell
   - Git Bash minimum version: 2.32.0
   - Run `npm install -g gh-switcher --force` if symlink issues occur
   
   **npm Registry Issues**:
   - Timeout errors: `npm config set registry https://registry.npmjs.org/`
   - Corporate proxy: See npm docs for proxy configuration
   - Use `npm install -g gh-switcher --verbose` for detailed error logs
   
   **Verify installation**:
   ```bash
   npm list -g gh-switcher  # Should show the package
   which ghs                # Should show path to command
   ghs --version           # Should show version
   ```
   ```

**README Restore Instructions** (add to plan):
```bash
# If README update fails or needs reverting:
cp README.md.backup README.md
echo "✅ README restored from backup"
```

**Validation**:
```bash
# Check badges will render
grep -c "shields.io" README.md | grep -q "3" && echo "✅ Badges added" || echo "❌ Missing badges"

# Verify npm install is first
grep -A1 "## Installation" README.md | grep -q "npm" && echo "✅ npm first" || echo "❌ npm not first"

# Ensure manual installation preserved
grep -q "curl\|wget" README.md && echo "✅ Manual install preserved" || echo "⚠️  Manual install missing"
```

#### 3.2 Create npm-specific Documentation
**Priority**: LOW  
**Time**: 15 minutes

**Create CHANGELOG.md**:
```bash
# Get current date
RELEASE_DATE=$(date +%Y-%m-%d)

cat > CHANGELOG.md << EOF
# Changelog

All notable changes to gh-switcher will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - $RELEASE_DATE

### Added
- Initial npm package release
- Core account switching functionality (\`ghs switch\`)
- SSH key management and validation
- Git hooks for commit protection (\`ghs guard\`)
- Project-specific user assignment (\`ghs assign\`)
- Multi-platform support (macOS, Linux, WSL)

### Security
- Secure storage of GitHub tokens
- SSH key permission validation (600)
- Pre-commit validation hooks

### Known Issues
- Windows support requires Git Bash or WSL
- Fish shell users may need to use bash wrapper

[0.1.0]: https://github.com/seconds-0/gh-switcher/releases/tag/v0.1.0
EOF

echo "✅ CHANGELOG.md created with date: $RELEASE_DATE"
```

### Phase 4: Testing & Validation (60 minutes)

#### 4.1 Local Package Testing
**Priority**: HIGH  
**Time**: 30 minutes

**Test Sequence**:

1. **Create test package**:
   ```bash
   # Clean any previous attempts
   rm -f gh-switcher-*.tgz
   
   # Create package
   npm pack
   
   # Verify created
   ls -la gh-switcher-*.tgz
   
   # Store package path
   PACKAGE_PATH=$(pwd)/$(ls gh-switcher-*.tgz)
   echo "Package created at: $PACKAGE_PATH"
   ```

2. **Inspect package contents** (CRITICAL):
   ```bash
   # List contents
   tar -tzf gh-switcher-*.tgz | sort
   
   # Should see ONLY:
   # package/LICENSE
   # package/README.md  
   # package/gh-switcher.sh
   # package/package.json
   
   # Check file sizes
   tar -tvzf gh-switcher-*.tgz
   
   # Verify total size < 100KB
   ls -lh gh-switcher-*.tgz
   
   # Extract and verify shebang
   tar -xzf gh-switcher-*.tgz package/gh-switcher.sh -O | head -1
   ```

3. **Test installation in isolation**:
   ```bash
   # Create test directory
   mkdir -p /tmp/npm-test && cd /tmp/npm-test
   
   # Copy package (use stored path)
   cp "$PACKAGE_PATH" .
   
   # Check for conflicts
   which ghs 2>/dev/null && echo "⚠️  Warning: ghs already exists"
   
   # Install globally
   npm install -g ./gh-switcher-*.tgz
   
   # Return to project
   cd -
   ```

4. **Verify command works**:
   ```bash
   # Check binary location
   which ghs
   # Expected: /usr/local/bin/ghs or ~/.npm-global/bin/ghs
   
   # Check it's a symlink
   ls -la $(which ghs)
   # Should show: ghs -> ../lib/node_modules/gh-switcher/gh-switcher.sh
   
   # Test execution
   ghs --version
   ghs --help
   ghs status
   ```

5. **Test core functions**:
   ```bash
   # Non-destructive tests only
   ghs users          # List users
   ghs status         # Current status
   ghs help          # Help text
   ghs guard status  # Guard status
   ```

6. **Test edge cases**:
   ```bash
   # Test with spaces in npm prefix (if possible)
   NPM_PREFIX_BACKUP=$(npm config get prefix)
   mkdir -p "/tmp/npm prefix with spaces"
   npm config set prefix "/tmp/npm prefix with spaces"
   npm install -g ./gh-switcher-*.tgz
   "/tmp/npm prefix with spaces/bin/ghs" --version
   npm config set prefix "$NPM_PREFIX_BACKUP"
   
   # Test upgrade scenario (if previously installed)
   npm install -g ./gh-switcher-*.tgz --force
   ```

7. **Clean test installation**:
   ```bash
   npm uninstall -g gh-switcher
   
   # Verify removal
   which ghs 2>/dev/null && echo "❌ Not removed" || echo "✅ Removed"
   
   # Check all traces removed
   find $(npm config get prefix) -name "*gh-switcher*" -o -name "*ghs*" 2>/dev/null
   ```

**Common Issues**:
- **"command not found"**: PATH issue, check npm prefix
- **"permission denied"**: Script not executable in package
- **Wrong files in package**: Check "files" in package.json
- **Spaces in paths**: Quote all path variables

**Checkpoint**: ✓ Local installation and commands work

#### 4.2 Cross-platform Testing
**Priority**: MEDIUM  
**Time**: 30 minutes

**Prerequisites**:
```bash
# Check if Docker available for Linux testing
command -v docker >/dev/null 2>&1 || echo "⚠️  Docker not found - skip Linux container tests"
```

**macOS Testing** (native):
```bash
# Test in different shells
zsh -c 'npm install -g ./gh-switcher-*.tgz && ghs --version'
bash -c 'npm install -g ./gh-switcher-*.tgz && ghs --version'

# Test in different terminals
# - Terminal.app
# - iTerm2  
# - VS Code integrated terminal
# - Warp
```

**Linux Testing** (Docker - if available):
```bash
# Ubuntu test
docker run --rm -it -v $(pwd):/workspace ubuntu:22.04 bash -c '
  apt-get update && apt-get install -y nodejs npm git
  cd /workspace
  npm install -g ./gh-switcher-*.tgz
  ghs --version
'

# Alpine test (different shell)
docker run --rm -it -v $(pwd):/workspace node:18-alpine sh -c '
  apk add git bash
  cd /workspace  
  npm install -g ./gh-switcher-*.tgz
  ghs --version
'

# Test with older Node.js
docker run --rm -it -v $(pwd):/workspace node:14-alpine sh -c '
  apk add git bash
  cd /workspace
  npm install -g ./gh-switcher-*.tgz
  ghs --version
'
```

**Windows Testing** (if available):
```bash
# In Git Bash (minimum version 2.32.0)
npm install -g ./gh-switcher-*.tgz
ghs --version

# Test WSL2 if available
wsl -e bash -c "npm install -g ./gh-switcher-*.tgz && ghs --version"

# Document any issues for README
```

**Alternative Package Managers** (optional):
```bash
# Test with yarn (if installed)
yarn global add file:$PWD/gh-switcher-*.tgz
yarn global list | grep gh-switcher

# Test with pnpm (if installed)  
pnpm add -g file:$PWD/gh-switcher-*.tgz
pnpm list -g | grep gh-switcher
```

**Platform Test Matrix**:
| Platform | Shell | Install | Execute | Notes |
|----------|-------|---------|---------|-------|
| macOS | zsh | ✓/✗ | ✓/✗ | |
| macOS | bash | ✓/✗ | ✓/✗ | |
| Ubuntu | bash | ✓/✗ | ✓/✗ | |
| Alpine | sh/bash | ✓/✗ | ✓/✗ | |
| Windows | Git Bash | ✓/✗ | ✓/✗ | Min v2.32.0 |
| Node 14 | various | ✓/✗ | ✓/✗ | Minimum supported |

### Phase 5: Pre-publish Checklist (30 minutes)

#### 5.1 Version Decision
**Priority**: MEDIUM  
**Time**: 10 minutes

**Version Guidelines**:
- **0.x.y**: Beta, may have breaking changes
- **1.x.y**: Stable API, production ready
- **x.0.0**: Major version, breaking changes
- **x.y.0**: Minor version, new features
- **x.y.z**: Patch version, bug fixes

**Decision Checklist**:
- [ ] All core features working?
- [ ] API likely to change?
- [ ] Ready for production use?
- [ ] Following semver?

**Update version if needed**:
```bash
# Current version
npx json -f package.json version

# Check for existing git tags
git tag -l "v*"

# Update (creates git commit and tag)
npm version 0.1.0 -m "chore: prepare for npm release v%s"

# If tag already exists, remove it first
git tag -d v0.1.0 2>/dev/null || true
git push origin :refs/tags/v0.1.0 2>/dev/null || true
```

#### 5.2 Final Quality Checks
**Priority**: HIGH  
**Time**: 10 minutes

**Run ALL checks**:
```bash
# Create check script with error handling
cat > pre-publish-check.sh << 'EOF'
#!/bin/bash
set -e

# Trap errors for cleanup
trap 'echo "❌ Check failed at line $LINENO"' ERR

echo "🔍 Running pre-publish checks..."

echo "1️⃣ Lint check..."
npm run lint || { echo "❌ Lint failed"; exit 1; }

echo "2️⃣ Test suite..."
npm test || { echo "❌ Tests failed"; exit 1; }

echo "3️⃣ CI simulation..."  
npm run ci-check || { echo "❌ CI check failed"; exit 1; }

echo "4️⃣ Git status..."
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Uncommitted changes:"
    git status --short
    exit 1
fi

echo "5️⃣ Package size..."
SIZE=$(npm pack --dry-run 2>&1 | grep "size:" | awk '{print $2}' || echo "unknown")
echo "Package size: ${SIZE}B"

echo "6️⃣ Author check..."
npx json -f package.json author.name | grep -v "REPLACE_WITH" || { echo "❌ Author placeholder found"; exit 1; }

echo "7️⃣ Shebang check..."
head -1 gh-switcher.sh | grep -q "^#!/bin/bash" || { echo "❌ Missing shebang"; exit 1; }

echo "✅ All checks passed!"
EOF

chmod +x pre-publish-check.sh
./pre-publish-check.sh
```

**Manual verifications**:
- [ ] gh-switcher.sh is executable
- [ ] No sensitive data in code
- [ ] No hardcoded paths
- [ ] Version number correct
- [ ] No placeholder text anywhere
- [ ] .npmrc not in repository

#### 5.3 Publish Dry Run
**Priority**: HIGH  
**Time**: 10 minutes

**Execute dry run**:
```bash
# Capture output
npm publish --dry-run 2>&1 | tee publish-dry-run.log

# Analyze output (handle format variations)
echo "=== Dry Run Analysis ==="
grep -E "size:|package size:" publish-dry-run.log || echo "Size info not found"
grep -E "files:|included files:" publish-dry-run.log || echo "Files info not found"
grep -E "total files:|files included:" publish-dry-run.log || echo "Total files info not found"

# Manual review
echo "=== Manual Review ==="
echo "Check the output above for:"
echo "- Package name is correct"
echo "- Version is correct"
echo "- Only 4-5 files included"
echo "- Total size under 100KB"
```

**Verify dry run shows**:
- [ ] Correct package name
- [ ] Correct version
- [ ] Only intended files (4-5 files max)
- [ ] Size under 100KB
- [ ] No errors or warnings

**Red flags**:
- Size over 1MB (something wrong)
- More than 10 files (check "files" field and .npmignore)
- Any file you don't recognize
- Warnings about missing fields
- Test files included

**Checkpoint**: ✓ Dry run clean, ready to publish

### Phase 6: Publishing (20 minutes)

#### 6.1 Execute Publish
**Priority**: HIGH  
**Time**: 5 minutes

**Final pre-flight**:
```bash
# Confirm logged in
npm whoami || { echo "❌ Not logged in"; exit 1; }

# Confirm version
echo "Publishing version: $(npx json -f package.json version)"

# Confirm package name  
echo "Package name: $(npx json -f package.json name)"

# Final confirmation
read -p "Ready to publish? (y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted"; exit 1; }
```

**PUBLISH**:
```bash
# For unscoped package
npm publish

# For scoped package  
npm publish --access public

# With OTP (if 2FA enabled)
# Will prompt: "This operation requires a one-time password:"
# Enter 6-digit code from authenticator

# If 2FA device unavailable, use backup code:
# Enter backup code from password manager
```

**Expected output**:
```
npm notice Publishing to https://registry.npmjs.org/
+ gh-switcher@0.1.0
```

**If publish fails**:
- **E403**: Name taken or permission denied
- **E401**: Not logged in  
- **EOTP**: Invalid or expired 2FA code
- **EPUBLISHCONFLICT**: Version already exists
- **ENEEDAUTH**: Run `npm login` again
- **Network timeout**: Check npm status page, retry

**Recovery if publish succeeds but verification fails**:
- Package is already published, cannot undo
- Fix issues locally
- Publish patch version (0.1.1)

**Record**: 
- Publish timestamp: ________________
- Version published: ________________

#### 6.2 Post-publish Verification
**Priority**: HIGH  
**Time**: 15 minutes

**Immediate checks** (may take 1-2 minutes to propagate):

1. **Registry verification**:
   ```bash
   # Wait 60 seconds for propagation
   echo "Waiting for npm registry propagation..."
   sleep 60
   
   # Check package exists
   npm view gh-switcher
   
   # Check specific version
   npm view gh-switcher@0.1.0
   
   # Check all versions
   npm view gh-switcher versions --json
   ```

2. **Web verification**:
   - Visit: https://www.npmjs.com/package/gh-switcher
   - Check:
     - [ ] README renders correctly
     - [ ] All badges working (no 404s now)
     - [ ] Install command correct
     - [ ] Keywords showing
     - [ ] License displayed
     - [ ] Repository link works
     - [ ] Author information correct (no placeholders)

3. **Fresh install test** (critical):
   ```bash
   # Test in clean environment
   cd /tmp
   
   # Clear npm cache
   npm cache clean --force
   
   # Install from registry
   npm install -g gh-switcher
   
   # Verify
   ghs --version
   
   # Return to project
   cd -
   ```

4. **Package metrics**:
   ```bash
   # Check initial stats
   npm view gh-switcher
   
   # Look for:
   # - downloads: will be 0 initially
   # - dist-tags: { latest: '0.1.0' }
   # - maintainers: your username
   ```

**Security check**:
```bash
# Check for vulnerabilities
npm audit --package gh-switcher 2>/dev/null || echo "Audit not available for new packages"

# Verify no tokens exposed
npm view gh-switcher dist.tarball | xargs curl -sL | tar -tz | grep -E "npmrc|\.env" && echo "⚠️  Sensitive files found!" || echo "✅ No sensitive files"
```

**Checkpoint**: ✓ Package live and verified

### Phase 7: Post-publish Tasks (30 minutes)

#### 7.1 Update Repository
**Priority**: MEDIUM  
**Time**: 15 minutes

**Update sequence**:

1. **Update installation docs**:
   ```bash
   # Verify README has npm as primary install
   grep -A5 "## Installation" README.md
   ```

2. **Update repository description**:
   - Go to: https://github.com/seconds-0/gh-switcher
   - Click gear icon next to About
   - Update description: "⚡ Lightning-fast GitHub account switcher - npm install -g gh-switcher"
   - Add topics: cli, github, npm-package

3. **Commit any changes**:
   ```bash
   git add -A
   git commit -m "docs: update docs for npm release"
   git push origin main
   ```

#### 7.2 Create GitHub Release
**Priority**: MEDIUM  
**Time**: 15 minutes

**Create release**:
```bash
# Create annotated tag (if not created by npm version)
git tag -a v0.1.0 -m "Initial npm release

- Published to npm registry
- Install: npm install -g gh-switcher
- First public release"

# Push tag
git push origin v0.1.0
```

**GitHub Release**:
1. Go to: https://github.com/seconds-0/gh-switcher/releases/new
2. Choose tag: v0.1.0
3. Title: "v0.1.0 - Initial npm release 🎉"
4. Description:
   ```markdown
   ## Installation
   ```bash
   npm install -g gh-switcher
   ```
   
   ## What's New
   - First release to npm registry
   - Full account switching functionality
   - SSH key management
   - Git hooks for protection
   - Cross-platform support
   
   ## Changelog
   [Copy from CHANGELOG.md]
   
   ## Verify Installation
   ```bash
   ghs --version
   ```
   ```
5. Publish release

### Phase 8: Future Automation (Optional)

#### 8.1 GitHub Action for npm Publishing
**Priority**: LOW  
**Time**: 30 minutes (separate task)

**Create** `.github/workflows/npm-publish.yml`:
```yaml
name: Publish to npm

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # For npm provenance
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          registry-url: 'https://registry.npmjs.org'
      
      - name: Verify package
        run: |
          npm run lint
          npm test
          npm pack --dry-run
      
      - name: Publish
        run: npm publish --provenance
        env:
          NODE_AUTH_TOKEN: ${{secrets.NPM_TOKEN}}
```

**Setup**:
1. Create npm automation token (publish-only scope)
2. Add as GitHub secret NPM_TOKEN
3. Test with next release

## Security Best Practices

### NPM Security Checklist
- [ ] **Never commit .npmrc** - Add to .gitignore
- [ ] **Use publish-only tokens** for automation
- [ ] **Enable 2FA** on npm account
- [ ] **Store backup codes securely** in password manager
- [ ] **Rotate tokens regularly** (every 90 days)
- [ ] **Review package contents** before each publish
- [ ] **Use npm provenance** for supply chain security

### Token Management
```bash
# Create automation token with minimal scope
# npm.com → Access Tokens → Generate New Token
# Select: Automation, Publish-only

# Never use:
npm config get //registry.npmjs.org/:_authToken  # Exposes token!

# Safe check:
npm config list | grep -c "registry.npmjs.org/:_authToken" && echo "✅ Token configured" || echo "❌ No token"
```

## Success Criteria

- [ ] Prerequisites validated before starting
- [ ] Package published to npm successfully
- [ ] `npm install -g gh-switcher` works globally
- [ ] `ghs` command available after installation
- [ ] Package page on npmjs.com looks professional
- [ ] No security warnings or vulnerabilities
- [ ] Installation works on macOS and Linux
- [ ] Documentation updated to prioritize npm installation
- [ ] GitHub release created with tag
- [ ] Repository description mentions npm
- [ ] No placeholder text published

## Rollback Plan

If critical issues found after publishing:

1. **Deprecate immediately** (DO NOT unpublish):
   ```bash
   npm deprecate gh-switcher@0.1.0 "Critical issue found, please use manual installation until v0.1.1"
   ```

2. **Fix issues**:
   - Create hotfix branch
   - Fix the issue
   - Full test cycle

3. **Publish patch**:
   ```bash
   npm version patch -m "fix: critical issue with [description]"
   npm publish
   ```

4. **Update deprecation**:
   ```bash
   npm deprecate gh-switcher@0.1.0 "Please update to v0.1.1"
   ```

## Critical Reminders

- **NEVER** use `npm unpublish` after 24 hours (against npm policy)
- **ALWAYS** use `npm deprecate` for issues
- **KEEP** 2FA enabled for security
- **TEST** the global install flow completely
- **VERIFY** the package name everywhere
- **CHECK** file permissions before publishing
- **REPLACE** all placeholder text before publishing
- **DOCUMENT** any platform-specific issues
- **BACKUP** 2FA recovery codes securely

## Agent Execution Tips

1. **Run prerequisites check first** - Phase 0 is mandatory
2. **Follow the checklist exactly** - each checkbox matters
3. **Save all command outputs** - useful for debugging
4. **Test destructively in Docker** - not on main system
5. **Verify each phase** before moving to next
6. **Stop on any red flags** - investigate fully
7. **Use the exact commands** provided - tested to work
8. **Document everything** - future publishes need history
9. **Check for placeholders** - multiple times before publish

## Post-Implementation Review

After publishing, document:
- Actual time taken per phase
- Any deviations from plan
- Unexpected issues encountered
- Platform-specific problems found
- Improvements for next release
- First user feedback received