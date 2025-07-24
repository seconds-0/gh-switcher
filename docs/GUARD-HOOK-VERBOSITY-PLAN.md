# Guard Hook Verbosity Improvement Plan

## Overview
Enhance guard hook error messages to provide clear, actionable guidance for both human users and AI agents when commits are blocked due to account mismatches.

## Current State

### Problem
Current error messages are terse and assume context that AI agents don't have:
```
❌ Account mismatch detected!

   Repository: my-project
   Expected:   work-account
   Current:    personal-account
   
   Switch with: ghs switch work-account
   Or bypass:   GHS_SKIP_HOOK=1 git commit ...
```

### Issues for AI Agents
1. No explanation of what a "guard hook" is
2. No context about why the commit was blocked
3. Limited actionable guidance
4. No indication this is a security feature, not an error

## Proposed Solution

### 1. Account Mismatch Error (Primary)

```bash
========================================================================
🛡️  GH-SWITCHER GUARD HOOK - COMMIT PROTECTION ACTIVE
========================================================================
This pre-commit hook prevents accidental commits with the wrong GitHub
identity. It checks if your current GitHub account matches the one
assigned to this project.

❌ COMMIT BLOCKED: GitHub Account Mismatch

WHAT'S HAPPENING:
  This repository:  my-project
  Assigned account: work-account  
  Current account:  personal-account
  
  The commit was blocked because you're using a different GitHub
  account than the one assigned to this project.

HOW TO FIX:

  1. Switch to the correct account (RECOMMENDED):
     $ ghs switch work-account
     
     This updates your git config to use the assigned identity.

  2. Override for just this commit (USE CAUTION):
     $ GHS_SKIP_HOOK=1 git commit -m "your message"
     
     ⚠️  This commit will use 'personal-account' instead of 'work-account'

  3. Change this project's assignment:
     $ ghs assign personal-account
     
     This assigns your current account to this project.

  4. Remove account checking for this project:
     $ ghs assign --remove
     
     This disables account validation for this repository.

For AI agents: Execute `ghs switch work-account` to resolve this issue.
========================================================================
```

### 2. Git Email Mismatch Warning

```bash
========================================================================
⚠️  GIT CONFIGURATION MISMATCH
========================================================================
Your git email doesn't match your GitHub account profile.

DETECTED MISMATCH:
  GitHub profile email: alice@company.com
  Current git email:    alice@personal.com
  
  While the commit will proceed, the email attribution may be wrong.

TO FIX:
  $ git config user.email "alice@company.com"
  
  Or re-run the account switch to update all settings:
  $ ghs switch work-account

For AI agents: Run `git config user.email "alice@company.com"`
========================================================================
```

### 3. No GitHub CLI Authentication

```bash
========================================================================
⚠️  GITHUB CLI NOT AUTHENTICATED
========================================================================
Cannot verify your GitHub account because 'gh' is not authenticated.

WHAT THIS MEANS:
  - The guard hook cannot check if you're using the right account
  - Your commit will proceed without validation
  - You may accidentally commit with the wrong identity

TO ENABLE PROTECTION:
  1. Authenticate GitHub CLI:
     $ gh auth login
     
  2. Then verify your current account:
     $ ghs status

For AI agents: This is a warning only. The commit will proceed.
========================================================================
```

### 4. No Account Assigned to Project

```bash
========================================================================
ℹ️  NO ACCOUNT ASSIGNED TO THIS PROJECT
========================================================================
This repository has no assigned GitHub account, so identity validation
is skipped.

TO ENABLE PROTECTION:
  Assign your current account to this project:
  $ ghs assign $(gh api user -q .login)
  
  Or assign a specific account:
  $ ghs assign work-account

For AI agents: No action needed. Commit will proceed.
========================================================================
```

## Implementation Details

### 1. Update Guard Hook Template
Modify the hook generation in `cmd_guard_install()` to include verbose messages.

### 2. Add Verbosity Control
```bash
# Environment variable to control verbosity
GHS_GUARD_VERBOSE="${GHS_GUARD_VERBOSE:-true}"

# In hook:
if [[ "$GHS_GUARD_VERBOSE" == "true" ]]; then
    # Show full verbose message
else
    # Show current terse message
fi
```

### 3. Message Formatting
- Use consistent header/footer separators (72 chars)
- Clear section headers (WHAT'S HAPPENING, HOW TO FIX)
- Numbered options with clear descriptions
- Special "For AI agents" section at the end

### 4. Testing Scenarios
1. Account mismatch - different user
2. Account mismatch - same user, different host
3. Git email mismatch warning
4. No gh authentication
5. No assigned account
6. With/without verbose mode

## Benefits

### For AI Agents
- Clear context about what's happening
- Explicit commands to run
- Understanding of whether to proceed or fix

### For Human Users  
- Educational about the security feature
- Multiple resolution options
- Less confusion and frustration

### For Maintainers
- Fewer support requests
- Self-documenting security feature
- Professional appearance

## Rollout Plan

1. Implement verbose messages in feature branch
2. Test all error scenarios locally
3. Update hook generation logic
4. Add tests for message formatting
5. Document the verbosity option
6. Create PR with examples

## Success Metrics

- AI agents can self-resolve guard hook blocks
- Reduced user confusion (fewer issues filed)
- Positive feedback on clarity
- No performance impact (messages only shown on error)