# Homebrew Tap Setup Plan for gh-switcher

## Overview
Create a Homebrew tap to allow macOS users to install gh-switcher via `brew install`. This is simpler than getting into homebrew-core and gives you full control over releases.

## Prerequisites
- GitHub account (seconds-0)
- Homebrew installed locally for testing
- gh-switcher v0.1.0 released on GitHub

## Step-by-Step Implementation

### Phase 1: Create Tap Repository (10 minutes)

#### 1.1 Create GitHub Repository
```bash
# Using GitHub CLI
gh repo create homebrew-tap --public --description "Homebrew tap for seconds-0 projects"

# Clone locally
git clone https://github.com/seconds-0/homebrew-tap.git
cd homebrew-tap
```

#### 1.2 Create Repository Structure
```bash
# Create formula directory
mkdir -p Formula

# Create README
cat > README.md << 'EOF'
# seconds-0 Homebrew Tap

## Usage

```bash
brew tap seconds-0/tap
brew install gh-switcher
```

## Available Formulas

- **gh-switcher** - Lightning-fast GitHub account switcher

## Documentation

See individual formula pages for more information.
EOF
```

### Phase 2: Create Formula (15 minutes)

#### 2.1 Get SHA256 Hash
```bash
# Download and get SHA256
curl -L https://github.com/seconds-0/gh-switcher/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
# Save this hash for the formula
```

#### 2.2 Create Formula File
Create `Formula/gh-switcher.rb`:

```ruby
class GhSwitcher < Formula
  desc "Lightning-fast GitHub account switcher for developers with multiple identities"
  homepage "https://github.com/seconds-0/gh-switcher"
  url "https://github.com/seconds-0/gh-switcher/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256_FROM_STEP_2.1"
  license "MIT"

  depends_on "git"
  depends_on "gh"

  def install
    bin.install "gh-switcher.sh" => "ghs"
  end

  test do
    assert_match "GitHub Project Switcher", shell_output("#{bin}/ghs help")
  end
end
```

**That's it!** The formula is intentionally simple because:
- gh-switcher is a bash script, not compiled code
- The shebang line handles bash requirements
- No complex installation needed

### Phase 3: Test Locally (10 minutes)

#### 3.1 Validate Formula
```bash
# Check formula style
cd homebrew-tap
brew style --fix Formula/gh-switcher.rb
```

#### 3.2 Test Installation
```bash
# Install from local formula
brew install --build-from-source Formula/gh-switcher.rb

# Test it works
ghs help
ghs status

# Test uninstall
brew uninstall gh-switcher
```

### Phase 4: Publish Tap (5 minutes)

#### 4.1 Commit and Push
```bash
git add .
git commit -m "Add gh-switcher formula v0.1.0"
git push origin main
```

#### 4.2 Test Remote Installation
```bash
# Add your tap
brew tap seconds-0/tap

# Install gh-switcher
brew install gh-switcher

# Verify
which ghs  # Should show /usr/local/bin/ghs or /opt/homebrew/bin/ghs
ghs help
```

### Phase 5: Update Documentation (10 minutes)

#### 5.1 Update gh-switcher README
Add to the installation section in README.md:

```markdown
### Via Homebrew (macOS)
```bash
brew tap seconds-0/tap
brew install gh-switcher
```

Note: The Homebrew installation creates a standalone `ghs` command. If you prefer shell integration for features like auto-switching, use the manual installation method instead.
```

#### 5.2 Create Update Instructions
Create `UPDATING.md` in homebrew-tap repo:

```markdown
# Updating Formulas

## When gh-switcher releases a new version:

1. Get the new SHA256:
   ```bash
   curl -L https://github.com/seconds-0/gh-switcher/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```

2. Update `Formula/gh-switcher.rb`:
   - Change the `url` to point to new version
   - Update the `sha256` with new hash

3. Test locally:
   ```bash
   brew reinstall gh-switcher
   ```

4. Commit and push:
   ```bash
   git add Formula/gh-switcher.rb
   git commit -m "gh-switcher: update to vX.Y.Z"
   git push
   ```

Users will get the update with `brew upgrade`.
```

## Testing Checklist

- [ ] Formula passes `brew style` check
- [ ] `brew install gh-switcher` completes without errors
- [ ] `ghs help` shows help text
- [ ] `ghs status` runs (may show "not configured")
- [ ] `brew uninstall gh-switcher` removes cleanly
- [ ] Remote installation works after pushing

## Common Issues & Solutions

### SHA256 Mismatch
```bash
# If you get wrong SHA256, recalculate:
curl -sL https://github.com/seconds-0/gh-switcher/archive/refs/tags/v0.1.0.tar.gz -o /tmp/gh-switcher.tar.gz
shasum -a 256 /tmp/gh-switcher.tar.gz
```

### Formula Rejected
```bash
# Fix style issues automatically
brew style --fix Formula/gh-switcher.rb
```

### Command Not Found After Install
```bash
# Check Homebrew's bin directory is in PATH
echo $PATH | grep -E "(brew|homebrew)/bin"

# If not, add to your shell profile:
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc  # Apple Silicon
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc     # Intel Mac
```

## Important Notes

1. **Standalone vs Sourced**: Homebrew installs create a standalone `ghs` command. This means:
   - ✅ All commands work: `ghs switch`, `ghs add`, etc.
   - ⚠️  Auto-switching on `cd` won't work (requires sourcing)
   - ⚠️  Shell aliases won't be available
   
   Users who need these features should use manual installation.

2. **Updates**: When you release a new version of gh-switcher:
   - Update the formula immediately
   - Users get updates with `brew upgrade`
   - No need to wait for approvals

3. **Multiple Versions**: You can support multiple versions:
   - `gh-switcher.rb` - latest version
   - `gh-switcher@0.1.rb` - specific version

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Example: GitHub's tap](https://github.com/github/homebrew-gh)

## Future Enhancements

1. **GitHub Action for Updates**: Automatically update formula when new releases are tagged
2. **Shell Integration Formula**: Separate formula that sets up sourcing for full features
3. **Analytics**: Enable Homebrew analytics to track installs
4. **Homebrew Core**: Once gh-switcher has sufficient users, submit to homebrew-core

## Time Estimate

- Total time: ~40 minutes
- Most time spent on: Testing and documentation
- Actual formula creation: ~5 minutes (it's very simple!)