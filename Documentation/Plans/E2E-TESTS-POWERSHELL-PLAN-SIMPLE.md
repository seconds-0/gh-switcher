# E2E Tests Plan - PowerShell (Simplified)

## Reality Check
gh-switcher is a bash/zsh script. PowerShell users can't use it directly. We just need to ensure we don't break their environment.

## The Tests (Just 2)

### Test 1: PowerShell Still Works After Installation
```bash
@test "e2e: powershell: doesn't break PowerShell startup" {
    # Skip if PowerShell not available
    command -v pwsh >/dev/null 2>&1 || skip "PowerShell not installed"
    
    # Install gh-switcher normally
    source "$script_path"
    
    # PowerShell should still start
    pwsh -NoProfile -Command "Write-Output 'PowerShell works'"
}
```

### Test 2: Document Workaround for PowerShell Users
```bash
@test "e2e: powershell: wrapper function provides basic access" {
    command -v pwsh >/dev/null 2>&1 || skip "PowerShell not installed"
    
    # Create simple wrapper
    mkdir -p ~/.config/powershell
    cat > ~/.config/powershell/ghs.ps1 << 'EOF'
function ghs {
    bash -c "source $HOME/.local/bin/gh-switcher.sh && ghs $($args -join ' ')"
}
EOF
    
    # Test wrapper works
    pwsh -NoProfile -Command ". ~/.config/powershell/ghs.ps1; ghs status"
}
```

## What We're NOT Testing
- Full PowerShell compatibility (impossible without rewrite)
- PowerShell prompt integration
- PowerShell modules
- Object pipeline integration
- Cross-platform PowerShell differences

## Documentation for PowerShell Users

Add to README:
```markdown
### PowerShell Users
gh-switcher is a bash/zsh script. PowerShell users can use this wrapper:

```powershell
# Add to your $PROFILE
function ghs {
    bash -c "source $HOME/.local/bin/gh-switcher.sh && ghs $($args -join ' ')"
}
```

Note: Requires bash or zsh installed (WSL, Git Bash, or brew).
```

## Future Consideration
If we get 100+ PowerShell users requesting support, consider a native PowerShell module. Until then, document the limitation.

That's it. Two tests, clear documentation, no false promises.