# Git Bash Minimal Testing Plan

## Goal
Ensure gh-switcher works on Git Bash without over-engineering.

## Core Testing Workflows (What Users Actually Do)

### 1. Installation & Basic Usage
```bash
# User downloads gh-switcher
curl -o gh-switcher.sh https://raw.githubusercontent.com/seconds-0/gh-switcher/main/gh-switcher.sh
chmod +x gh-switcher.sh

# Sources it
source gh-switcher.sh

# Adds a user
ghs add myuser --ssh-key ~/.ssh/id_rsa

# Switches accounts
ghs switch myuser

# Makes a commit
git commit -m "test"
```

### 2. What Could Break?
- **Nothing** - Git Bash handles paths automatically
- **SSH warnings** - Windows shows permissions differently
- **Maybe performance** - But only if it's really bad

## Implementation (1-2 days max)

### Day 1: Add Windows to CI
```yaml
# .github/workflows/ci.yml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
```

That's it. Run CI and see what happens.

### Day 2: Fix Only What Breaks

#### IF SSH permission warnings are confusing:
```bash
# In validate_ssh_key function, add:
if [[ "$OSTYPE" == "msys" ]] && ! chmod 600 "$ssh_key" 2>/dev/null; then
    echo "Note: SSH permissions can't be strictly set on Windows (this is normal)" >&2
fi
```

#### IF tests fail due to Git Bash differences:
```bash
# In specific failing test, add:
[[ "$OSTYPE" == "msys" ]] && skip "Not applicable on Git Bash"
```

#### IF nothing breaks:
Ship it. We're done.

## What We're NOT Doing

### No Complex Path Handling
Git Bash already converts:
- `C:\Users\alice` → `/c/Users/alice`
- `~` → `/c/Users/alice`
- Everything just works

### No Performance Tuning
If it's slow, users will tell us. Don't guess.

### No Special Git Bash Tests
The existing tests should work. If they don't, skip them.

### No Retry Logic
Don't add complexity for theoretical antivirus issues.

## Success Criteria

1. ✅ CI passes on windows-latest
2. ✅ Basic workflow works (add user, switch, commit)
3. ✅ No confusing error messages

## Total Effort: 1-2 days

- Hour 1-2: Add windows-latest to CI
- Hour 3-4: Fix any test failures (probably none)
- Hour 5-6: Add SSH permission note if needed
- Hour 7-8: Update README to mention Git Bash works

## The Key Insight

Git Bash exists to make Unix tools work on Windows. It already handles 90% of compatibility issues. We don't need to recreate that work.

Let Git Bash do its job. We just need to not break it.