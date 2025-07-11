# Multi-Host Support Implementation Plan

## Overview
Enable gh-switcher to work with multiple GitHub instances (github.com, GitHub Enterprise, etc.) while maintaining simplicity and <100ms performance.

## Problem Statement
Many developers work with both github.com and GitHub Enterprise instances. Currently, gh-switcher assumes github.com, making it unusable for enterprise users or those who work across multiple GitHub instances.

## Success Criteria
- Support multiple GitHub hosts (github.com, enterprise domains)
- Each profile can specify its host
- GitHub CLI auth switches correctly per host
- SSH testing works with custom hosts
- Maintains <100ms performance
- Backward compatible (existing profiles default to github.com)
- Simple UX - host complexity hidden unless needed

## Design Principles
1. **Host is a profile attribute** - Each user profile belongs to a specific host
2. **Backward compatible** - Existing profiles work without modification
3. **Smart defaults** - github.com is the default, no need to specify
4. **Host switching is implicit** - When you switch users, you switch hosts
5. **No over-engineering** - No host "management", just profile attributes

## Data Model Changes

### Current Profile Format (v3)
```
username|v3|name|email|ssh_key
```

### New Profile Format (v4)
```
username|v4|name|email|ssh_key|host
```

### Migration Strategy
- v3 profiles are treated as github.com profiles
- Automatic migration on profile edit/update
- No forced migration - v3 continues to work

## Implementation Plan

### Phase 0: Host Validation Function

```bash
# Validate host format
validate_host() {
    local host="$1"
    
    # Basic sanity check
    [[ -z "$host" ]] && { echo "❌ Host cannot be empty" >&2; return 1; }
    [[ ${#host} -gt 253 ]] && { echo "❌ Host too long" >&2; return 1; }
    
    # Must be a valid domain name (simplified check)
    # - Contains at least one dot
    # - Only alphanumeric, dots, and hyphens
    # - No protocol prefix
    # - No port suffix
    if [[ ! "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        echo "❌ Invalid host format: $host" >&2
        echo "   Expected format: github.com or github.company.com" >&2
        return 1
    fi
    
    # Must have at least one dot (not just 'github')
    if [[ ! "$host" =~ \. ]]; then
        echo "❌ Host must be a fully qualified domain" >&2
        echo "   Expected format: github.com or github.company.com" >&2
        return 1
    fi
    
    # No protocol prefix
    if [[ "$host" =~ ^https?:// ]]; then
        echo "❌ Host should not include protocol" >&2
        echo "   Use: github.com (not https://github.com)" >&2
        return 1
    fi
    
    # No port suffix
    if [[ "$host" =~ :[0-9]+$ ]]; then
        echo "❌ Host should not include port" >&2
        echo "   Use: github.com (not github.com:443)" >&2
        return 1
    fi
    
    return 0
}
```

### Phase 1: Profile Format Update

#### 1.1 Update Profile Storage
```bash
# Update _write_profile_entry_to_file()
_write_profile_entry_to_file() {
    local file="$1"
    local username="$2"
    local name="$3"
    local email="$4"
    local ssh_key="${5:-}"
    local host="${6:-github.com}"  # Default to github.com
    
    # Format: username|v4|name|email|ssh_key|host
    printf "%s|v4|%s|%s|%s|%s\n" "$username" "$name" "$email" "$ssh_key" "$host" >> "$file"
}
```

#### 1.2 Update Profile Reading
```bash
# Update profile_get() to handle both v3 and v4
profile_get() {
    local username="$1"
    # ... existing validation ...
    
    local profile_line
    profile_line=$(grep "^${username}|" "$GH_USER_PROFILES" | head -1)
    [[ -n "$profile_line" ]] || return 1
    
    # Detect version
    local version
    version=$(echo "$profile_line" | cut -d'|' -f2)
    
    case "$version" in
        v3)
            # Parse v3: username|v3|name|email|ssh_key
            local name email ssh_key
            IFS='|' read -r _ _ name email ssh_key <<< "$profile_line"
            
            echo "name:$name"
            echo "email:$email"
            echo "ssh_key:$ssh_key"
            echo "host:github.com"  # Default for v3
            ;;
        v4)
            # Parse v4: username|v4|name|email|ssh_key|host
            local name email ssh_key host
            IFS='|' read -r _ _ name email ssh_key host <<< "$profile_line"
            
            echo "name:$name"
            echo "email:$email"
            echo "ssh_key:$ssh_key"
            echo "host:${host:-github.com}"  # Fallback if empty
            ;;
        *)
            echo "❌ Unknown profile version: $version" >&2
            return 1
            ;;
    esac
}
```

### Phase 2: Command Updates

#### 2.1 Add Command Enhancement
```bash
# Add --host parameter to cmd_add()
cmd_add() {
    local username="${1:-}"
    local ssh_key=""
    local host="github.com"  # Default
    
    # Parse options
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key) ssh_key="$2"; shift 2 ;;
            --host) host="$2"; shift 2 ;;
            *) echo "❌ Unknown option: $1" >&2; return 1 ;;
        esac
    done
    
    # Validate host format (basic check)
    if [[ ! "$host" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid host format: $host" >&2
        echo "   Expected format: github.com or github.company.com" >&2
        return 1
    fi
    
    # Create profile with host
    profile_create "$username" "$username" "${username}@users.noreply.github.com" "$ssh_key" "$host"
}
```

#### 2.2 Edit Command Enhancement
```bash
# Add --host to cmd_edit options
case "$1" in
    --host)
        cmd_edit_validate_arg "$1" "$2" || return 1
        new_host="$2"
        changes_made=true
        shift 2
        ;;
esac
```

#### 2.3 Show Command Enhancement
```bash
# Display host in cmd_show()
echo "👤 $username"
echo "   Host: ${host}"  # Show which GitHub instance
echo "   Email: $email"
echo "   Name: $name"
```

### Phase 3: Profile Creation Updates

#### 3.1 Update profile_create signature
```bash
# Update profile_create() to accept host
profile_create() {
    local username="$1"
    local name="${2:-$username}"
    local email="${3:-}"
    local ssh_key="${4:-}"
    local host="${5:-github.com}"
    
    # Generate default email based on host
    if [[ -z "$email" ]]; then
        if [[ "$host" == "github.com" ]]; then
            email="${username}@users.noreply.github.com"
        else
            # Enterprise format: username@host
            email="${username}@${host}"
        fi
    fi
    
    # ... rest of validation ...
    
    # Write v4 format
    _write_profile_entry_to_file "$temp_file" "$username" "$name" "$email" "$ssh_key" "$host"
}
```

### Phase 4: Command Integration

#### 4.1 Switch Command Updates
```bash
# Update cmd_switch to show host info
cmd_switch() {
    # ... existing user resolution ...
    
    # Get target host
    local profile host
    profile=$(profile_get "$username") || return 1
    host=$(profile_get_field "$profile" "host")
    
    # Show what we're switching to
    echo "🔄 Switching to $username on $host"
    
    # Check if different host than github.com
    if [[ "$host" != "github.com" ]]; then
        echo "💡 For enterprise hosts, ensure you're authenticated:"
        echo "   gh auth status --hostname $host"
        echo "   If not: gh auth login --hostname $host"
    fi
    
    # Apply profile (existing code)
    profile_apply "$username" "local"
}
```

#### 4.2 List Users Enhancement
```bash
# Update cmd_users to show host
cmd_users() {
    # ... existing empty check ...
    
    echo "📋 Available users:"
    local i=1
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            local profile_info=""
            local host_info=""
            
            # Get profile details
            local profile
            if profile=$(profile_get "$username" 2>/dev/null); then
                local host=$(profile_get_field "$profile" "host")
                if [[ "$host" != "github.com" ]]; then
                    host_info=" ($host)"
                fi
                
                if user_has_ssh_key "$username"; then
                    profile_info=" [SSH]"
                else
                    profile_info=" [HTTPS]"
                fi
            fi
            
            echo "  $i. $username$profile_info$host_info"
            ((i++))
        fi
    done < "$GH_USERS_CONFIG"
}
```

### Phase 5: SSH Testing Updates

#### 5.1 Host-Aware SSH Testing
```bash
# Update test_ssh_auth() to accept host
test_ssh_auth() {
    local ssh_key="$1"
    local host="${2:-github.com}"
    
    # Test SSH with specific host
    local output
    if output=$(ssh -T "git@${host}" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=3 \
        -o IdentitiesOnly=yes \
        -o IdentityFile="$ssh_key" \
        2>&1); then
        true
    fi
    
    # Check output (same logic, host-agnostic)
    if [[ "$output" =~ "successfully authenticated" ]]; then
        return 0
    fi
    # ... rest of logic unchanged
}

# Update cmd_test_ssh to pass host
cmd_test_ssh() {
    # ... existing username resolution ...
    
    # Get profile and host
    local profile ssh_key host
    profile=$(profile_get "$username") || {
        [[ "$quiet" == "true" ]] && return 1
        echo "❌ User not found: $username"
        return 1
    }
    
    ssh_key=$(profile_get_field "$profile" "ssh_key")
    host=$(profile_get_field "$profile" "host")
    
    # ... existing SSH key checks ...
    
    [[ "$quiet" != "true" ]] && {
        echo "🔐 Testing SSH authentication for $username..."
        echo "   Host: $host"
        echo "   Key: ${ssh_key/#$HOME/~}"
    }
    
    # Test with host
    test_ssh_auth "$ssh_key" "$host"
    # ... rest unchanged
}

# Update cmd_add SSH testing
# In cmd_add after SSH key validation:
if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
    echo "🔐 Testing SSH authentication..."
    local result exit_code
    
    # Test against the specified host
    if result=$(test_ssh_auth "$ssh_key" "$host" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    # ... rest of error handling
fi
```

### Phase 6: Guard Hooks Update

#### 6.1 Simplified Host-Aware Validation
```bash
# Update guard_test() to show host info
guard_test() {
    local project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    local assigned=$(project_get_user "$project")
    
    # Get expected host from profile
    local profile expected_host
    profile=$(profile_get "$assigned" 2>/dev/null) || {
        echo "⚠️  No profile for assigned user: $assigned"
        return 0
    }
    expected_host=$(profile_get_field "$profile" "host")
    
    # Show host info if not github.com
    if [[ "$expected_host" != "github.com" ]]; then
        echo "ℹ️  Expected host: $expected_host"
        echo "   Ensure authenticated: gh auth status --hostname $expected_host"
    fi
    
    # Rest of validation continues normally
    # We can't reliably detect current gh host, so we inform instead
    local gh_user=$(gh api user -q .login 2>/dev/null || echo "")
    
    [[ -z "$gh_user" ]] && { 
        echo "⚠️  GitHub CLI not authenticated"
        if [[ "$expected_host" != "github.com" ]]; then
            echo "   Run: gh auth login --hostname $expected_host"
        else
            echo "   Run: gh auth login"
        fi
        return 0
    }
    
    # ... rest of existing validation
}
```

## User Experience

### Basic Usage (github.com)
No change for github.com users:
```bash
ghs add alice
ghs switch alice
```

### Enterprise Usage
Explicit host for enterprise:
```bash
ghs add work-alice --host github.company.com
ghs switch work-alice  # Automatically uses github.company.com
```

### Mixed Usage
```bash
# Personal github.com account
ghs add personal

# Work enterprise account  
ghs add work --host github.company.com

# Switch seamlessly
ghs switch personal  # Uses github.com
ghs switch work      # Uses github.company.com
```

### Status Shows Host
```bash
$ ghs show work
👤 work
   Host: github.company.com
   Email: work@company.com
   Status: Active ✅
```

## Migration Examples

### Existing v3 Profile
```
alice|v3|Alice|alice@example.com|~/.ssh/id_rsa
```

### After First Edit (Auto-Migrated to v4)
```
alice|v4|Alice|alice@example.com|~/.ssh/id_rsa|github.com
```

### New Enterprise Profile
```
work|v4|Work User|work@company.com|~/.ssh/id_rsa_work|github.company.com
```

## Testing Plan

### Unit Tests

1. **Profile Format Tests** (`test_profile_multihost.bats`)
   ```bash
   @test "profile_get handles v3 format with default host" {
       # Create v3 profile
       echo "alice|v3|Alice|alice@example.com|~/.ssh/id_rsa" > "$GH_USER_PROFILES"
       
       run profile_get "alice"
       assert_success
       assert_output_contains "host:github.com"
   }
   
   @test "profile_get handles v4 format with custom host" {
       # Create v4 profile
       echo "work|v4|Work User|work@company.com|~/.ssh/work|github.company.com" > "$GH_USER_PROFILES"
       
       run profile_get "work"
       assert_success
       assert_output_contains "host:github.company.com"
   }
   
   @test "host validation accepts valid formats" {
       run validate_host "github.com"
       assert_success
       
       run validate_host "github.company.com"
       assert_success
       
       run validate_host "github.internal.corp.net"
       assert_success
   }
   
   @test "host validation rejects invalid formats" {
       run validate_host "github"
       assert_failure
       
       run validate_host "github.com:8080"
       assert_failure
       
       run validate_host "https://github.com"
       assert_failure
   }
   ```

2. **Command Tests** (`test_multihost_commands.bats`)
   ```bash
   @test "cmd_add accepts --host parameter" {
       run ghs add enterprise --host github.company.com
       assert_success
       assert_output_contains "Added enterprise"
       
       # Verify profile has host
       run profile_get "enterprise"
       assert_output_contains "host:github.company.com"
   }
   
   @test "cmd_edit can update host" {
       # Add user first
       ghs add testuser
       
       # Edit host
       run ghs edit testuser --host github.enterprise.com
       assert_success
       
       # Verify update
       run profile_get "testuser"
       assert_output_contains "host:github.enterprise.com"
   }
   
   @test "cmd_users shows host for non-github.com" {
       ghs add personal
       ghs add work --host github.company.com
       
       run ghs users
       assert_success
       assert_output_contains "1. personal [HTTPS]"
       assert_output_contains "2. work [HTTPS] (github.company.com)"
   }
   ```

3. **SSH Testing** (`test_ssh_multihost.bats`)
   ```bash
   @test "test_ssh_auth uses custom host" {
       # Mock SSH for enterprise
       cat > "$TEST_HOME/ssh" << 'EOF'
   #!/bin/bash
   if [[ "$*" =~ "-T git@github.enterprise.com" ]]; then
       echo "Hi user! You've successfully authenticated" >&2
       exit 1
   fi
   EOF
       chmod +x "$TEST_HOME/ssh"
       export PATH="$TEST_HOME:$PATH"
       
       run test_ssh_auth "$TEST_HOME/.ssh/key" "github.enterprise.com"
       assert_success
   }
   ```

### Integration Tests

1. **Multi-Host Workflow** (`test_multihost_workflow.bats`)
   ```bash
   @test "complete workflow with multiple hosts" {
       # Add github.com user
       run ghs add personal --ssh-key ~/.ssh/personal
       assert_success
       
       # Add enterprise user
       run ghs add work --host github.company.com --ssh-key ~/.ssh/work
       assert_success
       
       # List shows both with hosts
       run ghs users
       assert_output_contains "personal [SSH]"
       assert_output_contains "work [SSH] (github.company.com)"
       
       # Switch to enterprise
       run ghs switch work
       assert_output_contains "Switching to work on github.company.com"
       
       # Show displays host
       run ghs show work
       assert_output_contains "Host: github.company.com"
   }
   ```

### Migration Tests

1. **V3 to V4 Migration** (`test_migration.bats`)
   ```bash
   @test "v3 profiles auto-migrate on edit" {
       # Create v3 profile
       echo "olduser|v3|Old User|old@example.com|~/.ssh/old" > "$GH_USER_PROFILES"
       
       # Edit triggers migration
       run ghs edit olduser --name "Updated User"
       assert_success
       
       # Check migrated to v4
       run cat "$GH_USER_PROFILES"
       assert_output_contains "|v4|"
       assert_output_contains "|github.com"
   }
   ```

## Implementation Order

1. **Profile format v4** - Add host field, maintain backward compatibility
2. **Update commands** - Add --host to add/edit commands
3. **GitHub CLI integration** - Host-aware authentication checks
4. **SSH testing updates** - Support custom hosts
5. **Guard hooks** - Multi-host validation
6. **Documentation** - Update help and examples

## Risks & Mitigations

- **Risk**: Breaking existing profiles
  - **Mitigation**: v3 profiles work unchanged, auto-migrate on edit

- **Risk**: Complex UX for single-host users
  - **Mitigation**: github.com is default, no need to specify

- **Risk**: GitHub CLI auth complexity
  - **Mitigation**: Clear error messages with exact commands to run

- **Risk**: Performance impact
  - **Mitigation**: No new network calls, host is just a string field

## Out of Scope

- Host "management" commands (add-host, remove-host, etc.)
- Automatic host discovery
- Host aliases or shortcuts
- Per-host configuration beyond profiles
- OAuth token management