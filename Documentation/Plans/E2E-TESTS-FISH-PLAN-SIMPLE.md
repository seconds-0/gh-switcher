# E2E Tests Plan - Fish Shell (Simplified)

## Reality Check
Fish has completely different syntax. We can't source bash scripts directly. We provide a wrapper function.

## The Tests (Just 3)

### Test 1: Wrapper Function Works
```bash
@test "e2e: fish: wrapper function provides ghs command" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    # Create wrapper function
    mkdir -p ~/.config/fish/functions
    echo 'function ghs
        bash -c "source $HOME/.local/bin/gh-switcher.sh && ghs $argv"
    end' > ~/.config/fish/functions/ghs.fish
    
    # Test it works
    fish -c "ghs status"
}
```

### Test 2: User Switching Works Across Shells
```bash
@test "e2e: fish: switches persist between fish and bash" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    # Switch in bash
    source "$script_path"
    ghs add testuser
    ghs switch testuser
    
    # Verify in fish
    fish -c "ghs status" | grep -q testuser
}
```

### Test 3: Git Config Updates Work
```bash
@test "e2e: fish: git operations work after switching" {
    command -v fish >/dev/null 2>&1 || skip "Fish not installed"
    
    # Setup wrapper
    mkdir -p ~/.config/fish/functions
    echo 'function ghs
        bash -c "source $HOME/.local/bin/gh-switcher.sh && ghs $argv"
    end' > ~/.config/fish/functions/ghs.fish
    
    # Switch user in fish
    fish -c "ghs add fishuser; ghs switch fishuser"
    
    # Verify git config updated
    fish -c "git config user.name" | grep -q fishuser
}
```

## What We're NOT Testing
- Fish syntax compatibility (impossible)
- Fish completions (nice-to-have, not critical)
- Fish prompt integration
- Universal variables
- Fish events
- Abbreviations

## Installation Instructions for Fish Users

```fish
# One-time setup
echo 'function ghs
    bash -c "source $HOME/.local/bin/gh-switcher.sh && ghs $argv"
end' > ~/.config/fish/functions/ghs.fish
```

## Optional: Basic Completions
If we're feeling generous, provide basic completions:
```fish
complete -c ghs -f -a "status switch add remove users"
```

That's it. Fish users get a working `ghs` command. No promises about deep integration.